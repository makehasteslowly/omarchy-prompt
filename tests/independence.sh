#!/bin/bash
# Independence test for makehasteslowly's three plugins: Heliolune, Elementa
# Spaces and Prompt. Runs the bar with every combination of them present
# (all seven) and checks that each one present loads, answers or draws, and
# logs no errors, whatever the others are doing.
#
# It edits ~/.config/omarchy/shell.json, so it is careful:
#   - backs the file up first, writes every change atomically (temp + rename),
#   - stops, without restoring over it, if anything else changes the file,
#   - restores the backup at the end and checks it is byte-identical.
# Your bar blinks while it runs (a few minutes). Usage: tests/independence.sh
set -u
C="$HOME/.config/omarchy/shell.json"
WORK=$(mktemp -d)
BACKUP="$WORK/shell.backup.json"
cp -p "$C" "$BACKUP"
IDS="makehasteslowly.heliolune makehasteslowly.elementa makehasteslowly.prompt"

python3 - "$C" <<'EOF' || { echo "All three plugins must be on the bar to start."; exit 2; }
import json,sys
d=json.load(open(sys.argv[1])); ids={e.get('id') for s in d['bar']['layout'].values() if isinstance(s,list) for e in s}
sys.exit(0 if {"makehasteslowly.heliolune","makehasteslowly.elementa","makehasteslowly.prompt"} <= ids else 1)
EOF

# Write the backup minus the given plugin ids, atomically; remember what we wrote
apply() {
  python3 - "$C" "$BACKUP" "$WORK/expected.json" "$@" <<'EOF'
import json,os,sys
C,B,E=sys.argv[1:4]; drop=set(sys.argv[4:])
d=json.load(open(B))
for k,v in d['bar']['layout'].items():
    if isinstance(v,list): d['bar']['layout'][k]=[e for e in v if e.get('id') not in drop]
tmp=os.path.join(os.path.dirname(C),'.shell.json.independence')
with open(tmp,'w') as f: json.dump(d,f,indent=2,ensure_ascii=False); f.write("\n"); f.flush(); os.fsync(f.fileno())
os.chmod(tmp,0o600); os.replace(tmp,C)
json.dump(d,open(E,'w'))
EOF
}
# True if the live file still holds what we last wrote (nobody else touched it)
untouched() {
  python3 - "$C" "$WORK/expected.json" <<'EOF'
import json,sys
sys.exit(0 if json.load(open(sys.argv[1]))==json.load(open(sys.argv[2])) else 1)
EOF
}
restore() {
  local tmp="$(dirname "$C")/.shell.json.restore"
  cp -p "$BACKUP" "$tmp" && mv -f "$tmp" "$C"
  omarchy-restart-shell >/dev/null 2>&1
  sleep 3
  if cmp -s "$C" "$BACKUP"; then echo "Config restored (byte-identical to the backup)."
  else echo "WARNING: config differs from the backup; the backup is at $BACKUP"; fi
}

P0=$(hyprctl cursorpos)
pass=0; fail=0
printf "%-28s %-11s %-11s %-11s %s\n" "present" heliolune elementa prompt "log"
for combo in "H E P" "H E" "H P" "E P" "H" "E" "P"; do
  drop=""; present=""
  for k in H E P; do
    case $k in H) id=makehasteslowly.heliolune;; E) id=makehasteslowly.elementa;; P) id=makehasteslowly.prompt;; esac
    if [[ " $combo " == *" $k "* ]]; then present="$present ${id#makehasteslowly.}"; else drop="$drop $id"; fi
  done
  apply $drop
  omarchy-restart-shell >/dev/null 2>&1
  for i in $(seq 1 30); do pgrep -x quickshell >/dev/null && omarchy-shell shell >/dev/null 2>&1; sleep 1; [[ $i -ge 6 ]] && break; done
  sleep 5
  if ! untouched; then echo "shell.json was changed by something else during the test; stopping without restoring over it."; echo "Backup: $BACKUP"; exit 3; fi
  hyprctl dispatch 'hl.dsp.cursor.move({x=1400,y=450})' >/dev/null; sleep 0.5
  LOG=$(ls -t /run/user/$(id -u)/quickshell/by-pid/*/log.log | head -1)
  res=()
  # Heliolune and Elementa answer their own IPC; Prompt has none, so it is
  # checked by its ink at the left end of the bar
  for name in heliolune elementa prompt; do
    if [[ " $present " != *" $name "* ]]; then res+=("-"); continue; fi
    if [[ $name == prompt ]]; then
      grim -g "0,0 40x30" "$WORK/prompt-$combo.png" 2>/dev/null
      # lit = pixels clearly brighter than the darkest third of the crop
      lit=$(python3 - "$WORK/prompt-$combo.png" <<'PY'
import subprocess,sys,re
out=subprocess.check_output(['magick',sys.argv[1],'-colorspace','Gray','txt:-']).decode().splitlines()[1:]
v=[int(m.group(1)) for l in out if (m:=re.match(r'\d+,\d+: \((\d+)',l))]
v=[x*255//65535 for x in v] if max(v)>255 else v   # 16-bit captures to 0..255
bg=sorted(v)[len(v)//3]
print(sum(1 for x in v if x>bg+50))
PY
)
      [[ ${lit:-0} -ge 8 ]] && res+=("draws") || res+=("BLANK")
    else
      omarchy-shell makehasteslowly.$name refresh >/dev/null 2>&1 && res+=("answers") || res+=("NO-ANSWER")
    fi
  done
  errs=$(grep -aiE 'TypeError|ReferenceError|failed|error' "$LOG" | grep -aiE 'makehasteslowly\.(heliolune|elementa|prompt)' | grep -v "outside of the config" | wc -l)
  logres=$([[ $errs -eq 0 ]] && echo clean || echo "$errs ERRORS")
  printf "%-28s %-11s %-11s %-11s %s\n" "${present# }" "${res[0]}" "${res[1]}" "${res[2]}" "$logres"
  if [[ " ${res[*]} $logres " == *" BLANK "* || " ${res[*]} " == *"NO-ANSWER"* || $errs -ne 0 ]]; then fail=$((fail+1))
    [[ $errs -ne 0 ]] && grep -aiE 'TypeError|ReferenceError|failed|error' "$LOG" | grep -aiE 'makehasteslowly' | grep -v "outside of the config" | tail -3 | sed 's/^/      /'
  else pass=$((pass+1)); fi
done
restore
hyprctl dispatch "hl.dsp.cursor.move({x=${P0%,*},y=${P0#*, }})" >/dev/null
echo "Independence: $pass passed, $fail failed"
[[ $fail -eq 0 ]]

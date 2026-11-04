#!/bin/bash
# Live test: renders every Portal mark on the running bar and checks it
# against the widget that follows it (gap, bottom line, height), in each
# size, then scans the shell log for Portal errors. Settings are changed with
# omarchy-bar (the safe, serialized path) and restored at the end.
#
# Needs: Portal at the far left of a horizontal bar with a glyph widget
# (e.g. Elementa Spaces) after it; grim, ImageMagick, python3.
# Usage: tests/live.sh [output-dir]
set -u
P=makehasteslowly.portal
OUT=${1:-$(mktemp -d)}
mkdir -p "$OUT"
MARKS=$(python3 -c "import json;m=json.load(open('$(dirname "$0")/../manifest.json'));print(' '.join(o['value'] for o in [s for s in m['barWidget']['schema'] if s['key']=='mark'][0]['options'] if o['value']!='elementa'))")
SIZES="follow large standard"
SCALE=$(hyprctl monitors -j | python3 -c "import json,sys;print([m for m in json.load(sys.stdin) if m['focused']][0]['scale'])")

OM=$(omarchy-bar get $P mark); OZ=$(omarchy-bar get $P size); OW=$(omarchy-bar get $P weight)
P0=$(hyprctl cursorpos)
restore() {
  omarchy-bar set $P mark "${OM:-classic}" >/dev/null; omarchy-bar set $P size "${OZ:-follow}" >/dev/null
  omarchy-bar set $P weight "${OW:-light}" >/dev/null
  hyprctl dispatch "hl.dsp.cursor.move({x=${P0%,*},y=${P0#*, }})" >/dev/null
}
trap restore EXIT
hyprctl dispatch 'hl.dsp.cursor.move({x=1400,y=450})' >/dev/null
LOG=$(ls -t /run/user/$(id -u)/quickshell/by-pid/*/log.log | head -1)
LOGSTART=$(wc -l < "$LOG")

measure() {   # prints: gapP gapN bottomP bottomN heightP heightN (logical px)
  python3 - "$1" "$SCALE" <<'EOF'
import subprocess,sys,re
img,s=sys.argv[1],float(sys.argv[2])
out=subprocess.check_output(['magick',img,'txt:-']).decode().splitlines()[1:]
px={}
for l in out:
    m=re.match(r'(\d+),(\d+): \((\d+),(\d+),(\d+)',l)
    if m:
        v=[int(m.group(i)) for i in (3,4,5)]
        if max(v)>255: v=[c//257 for c in v]
        px[(int(m.group(1)),int(m.group(2)))]=max(v)
W=max(x for x,y in px)+1; Y0,Y1=int(4*s),int(20*s)
vals=sorted(px[(x,y)] for x in range(W) for y in range(Y0,Y1)); bg=vals[len(vals)//3]
col=[max(px.get((x,y),0) for y in range(Y0,Y1)) for x in range(W)]
rough=[x for x in range(W) if col[x]>bg+40]
groups=[];cur=[]
for x in rough:
    if cur and x-cur[-1]>3: groups.append(cur); cur=[]
    cur.append(x)
if cur: groups.append(cur)
res=[]
for g in groups[:3]:
    lo,hi=max(0,g[0]-2),min(W,g[-1]+3)
    peak=max(col[x] for x in range(lo,hi)); th=bg+(peak-bg)/2   # edge at half the glyph's own brightness
    xs=[x for x in range(lo,hi) if col[x]>th]
    ys=[y for x in xs for y in range(Y0,Y1) if px.get((x,y),0)>th]
    res.append((xs[0],xs[-1],min(ys),max(ys)))
if len(res)<3: print("nan nan nan nan nan nan"); sys.exit()
p,a,b=res
print(f"{(a[0]-p[1]-1)/s:.2f} {(b[0]-a[1]-1)/s:.2f} {p[3]/s:.2f} {a[3]/s:.2f} {(p[3]-p[2]+1)/s:.2f} {(a[3]-a[2]+1)/s:.2f}")
EOF
}

TOL=$(python3 -c "print(round(1.0/$SCALE + 0.05, 2))")   # one device pixel, in logical px
pass=0; fail=0
printf "%-10s %-9s %8s %8s %9s %8s  %s\n" mark size gap need bottom height result
for z in $SIZES; do
  omarchy-bar set $P size $z >/dev/null; sleep 2
  for mk in $MARKS; do
    omarchy-bar set $P mark $mk >/dev/null; sleep 1.1
    f="$OUT/$z-$mk.png"; grim -g "0,0 160x34" "$f"
    read gP gN bP bN hP hN < <(measure "$f")
    verdict=$(python3 - <<EOF
gP,gN,bP,bN,hP,hN,tol,z="$gP","$gN","$bP","$bN","$hP","$hN",$TOL,"$z"
import math
v=[float(x) for x in (gP,gN,bP,bN,hP,hN)]
if any(math.isnan(x) for x in v): print("FAIL no-glyphs"); raise SystemExit
gP,gN,bP,bN,hP,hN=v
why=[]
if z!="standard":
    # Even gaps and a shared bottom line, to within one device pixel (plus one for
    # the neighbor's own glyphs, which differ by a pixel among themselves)
    if abs(gP-gN)>2*tol: why.append(f"gap {gP-gN:+.1f}")
    if abs(bP-bN)>2*tol: why.append(f"bottom {bP-bN:+.1f}")
if hP<0.75*hN: why.append(f"small {hP:.1f}")
if hP>1.45*hN: why.append(f"large {hP:.1f}")
print("ok" if not why else "FAIL "+", ".join(why))
EOF
)
    printf "%-10s %-9s %8s %8s %9s %8s  %s\n" "$mk" "$z" "$gP" "$gN" "$bP/$bN" "$hP" "$verdict"
    [[ $verdict == ok ]] && pass=$((pass+1)) || fail=$((fail+1))
  done
done

# Bold weight renders for every drawn mark (no errors, not blank)
omarchy-bar set $P size follow >/dev/null; omarchy-bar set $P weight bold >/dev/null; sleep 1.5
for mk in $MARKS; do
  omarchy-bar set $P mark $mk >/dev/null; sleep 0.9
  f="$OUT/bold-$mk.png"; grim -g "0,0 160x34" "$f"
  read gP _ _ _ hP _ < <(measure "$f")
  if [[ $hP == nan ]]; then echo "bold/$mk: FAIL blank"; fail=$((fail+1)); else pass=$((pass+1)); fi
done

ERR=$(tail -n +$LOGSTART "$LOG" | grep -aiE 'TypeError|ReferenceError|failed|error' | grep -ai 'makehasteslowly.portal' | grep -v "outside of the config")
if [[ -n $ERR ]]; then echo "Shell log errors:"; echo "$ERR" | tail -5; fail=$((fail+1)); else pass=$((pass+1)); fi

echo "Live: $pass passed, $fail failed  (captures in $OUT)"
[[ $fail -eq 0 ]]

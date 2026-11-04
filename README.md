# Portal

The Omarchy menu button as a terminal glyph, in your choice of fifteen styles.

| Mark | Style |
|---|---|
| **Classic** | `>_`, the prompt itself |
| **Dollar** | `$_`, the shell prompt |
| **Arrow** | `➜_`, Oh My Zsh's arrow |
| **Lambda** | `λ_`, the functional prompt |
| **Modern** | a heavy chevron and a block cursor |
| **Cursor** | the block cursor alone |
| **Window** | a terminal window with three title-bar dots |
| **Retro** | a little CRT monitor with a prompt on screen |
| **Deco** | Art Deco streamline chevrons in a cut-corner frame |
| **Atomic** | a Googie boomerang prompt and a starburst cursor |
| **Nouveau** | a whiplash prompt ending in a curl, and a leaf for the cursor |
| **Alchemical** | the fire triangle laid on its side as the prompt |
| **Zen** | an ensō around a waiting cursor |
| **Seal** | 令, "command", in a vermilion scholar's seal |
| **Pixel** | an 8-bit prompt |

Also the Omarchy, Arch Linux, Hyprland and Linux marks.

Every mark is drawn on one grid and centered on its ink rather than its font box. By default Portal measures the glyph of whatever widget follows it on the bar and matches its height and vertical center, so the two read as one row; **Standard** keeps it at 12 px. **Match Elementa** picks the style of [Elementa Spaces](https://github.com/makehasteslowly/omarchy-elementa-spaces)' tradition and follows its Light/Bold (Elemental → Deco, Alchemical → Alchemical, Godai → Zen, Wu Xing → Seal).

Left-click opens the Omarchy menu, right-click opens a terminal, and middle-click steps to the next glyph.

## Settings
- **Mark**: one of the styles above, a system mark, or Match Elementa.
- **Size**: Match next widget, Large (15% bigger than that), or Standard (12 px).
- **Weight**: Light or Bold strokes.
- **Color**: the bar's text color, or the theme accent. The seal keeps its vermilion.

No dependencies, no network.

## Tests
- `node tests/marks.mjs` checks that every mark in settings can be drawn, placed and reached by middle-click, and that the defaults, README and manifest agree.
- `tests/live.sh` renders every mark on the running bar in each size and Bold, checks gap, bottom line and height against the next widget, and scans the shell log. Settings are restored afterwards.

## License
MIT

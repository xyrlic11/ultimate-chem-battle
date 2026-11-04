# theme/

`game_theme.tres` is wired up as the project default theme via
`project.godot` → `[gui] theme/custom`.

## Current setup: SystemFont (no font file shipped)

The theme uses a `SystemFont`, which resolves against fonts **installed on the
player's machine** at runtime. Preference order:

1. `Leelawadee UI` — Windows, covers Latin + Thai in one typeface
2. `Noto Sans Thai` — Linux / Android / anyone with Google's Noto set
3. `Sarabun` — very common Thai UI font
4. `Tahoma`, `Segoe UI`, `Noto Sans`, `DejaVu Sans` — fallbacks

`allow_system_fallback = true` handles anything still missing, which is what
makes emoji (💰 🧪 💥 …) render — those come from Segoe UI Emoji on Windows.

### Why not just bundle Leelawadee UI?

It ships with Windows and is **not redistributable**. Copying
`C:\Windows\Fonts\LeelawUI.ttf` into this repo would be a licensing violation
the moment you hand the game to anyone. Same for the UPC Thai family.

## To bundle a real font (required for Web export)

A browser exposes no font list to Godot, so **a Web export will render Thai as
tofu boxes (□□□) with the current setup**. Desktop and Android are fine.

To fix:

1. Download **Noto Sans Thai** (SIL Open Font License, free to redistribute):
   <https://fonts.google.com/noto/specimen/Noto+Sans+Thai>
   Take `NotoSansThai-Regular.ttf` from the download.
2. Drop it in this folder as `theme/fonts/NotoSansThai-Regular.ttf`.
3. Open `game_theme.tres` in the Godot editor, replace the `SystemFont` in
   `default_font` with a `FontFile` pointing at that `.ttf`.
4. Emoji still will not appear on Web — Noto Sans Thai has no emoji glyphs and
   there is no system to fall back to. Either also bundle `NotoEmoji-Regular.ttf`
   as a fallback font on the `FontFile`, or replace the emoji in the UI strings
   with drawn icons.

Keep the OFL license file next to any font you bundle.

## Layout warning

Thai script has tall stacked diacritics (สระบน / วรรณยุกต์), so Thai lines are
taller than Latin ones at the same font size. `PROGRESS.md` documents a real bug
where `ShopPanel`'s fixed-height children overflowed and squeezed the recipe list
to zero height. **If you change `default_font_size` here, re-check the Shop
screen visually** — that class of bug does not show up in headless tests.

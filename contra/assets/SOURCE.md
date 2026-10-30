# Rifle sprite sheet

`mario-rifle-sheet.png` is the unchanged PNG supplied by the user on
23 October 2026, originally attached as
`codex-clipboard-df776c70-1f1c-48b2-b39e-5ef485954689.png`.
Additional sprite-sheet attribution supplied by the user is recorded in the
[project credits](../../CREDITS.md).

Its three rows per group contain ready, recoil and unarmed variants.
`tools/sprite_assets.py` records the source rectangles and converts the exact
body/gun pixels into separate NES palette layers. The rifles use Contra's
existing stage weapon palette, as requested, preserving native enemy colors.
SMB1 tiles from the local ROM remain the source for poses not in the sheet.

# Supplied Contra title

The user supplied `title-screen.png` on 2026-10-23 for this port. No author name was supplied. SHA-256: `4056eb98da03901232d1e727a88f17b7e775276c240444b3f941f43192a8fe90`.

`tools/title_assets.py` decomposes every source pixel into background tiles and sprites. A sprite-zero split selects the second background pattern table at scanline 128. The supplied mushroom is the movable menu cursor. The image uses 11 RGB colors; they map to the corresponding NES palette entries, with tiny differences between the source RGB palette and the emulator's standard NES RGB palette.

`title-palette-rgb.bin` is the 64-color RGB table measured from isolated, uniformly blank NES frames in Mesen. The measurement ROM/script are in `build/palette-probe.nes` and `build/palette-probe.lua`; this RGB table is used only to construct screenshot verification fixtures. The ROM stores NES color indexes. Tests compare all 61,440 screen pixels in both player modes and check the raster transition.


## Independent blinking (23 October 2026)

The user supplied `title-blink-reference.gif` from the Discord attachment
`buhlink.gif` in this conversation. SHA-256:
`467e275d1985455d5cd8a1dbd352a2a3147a07b5e98f58ededf977023804ffb3`.
Its open, closed and half-open eye frames are translated (+6,-2) to match
the installed title's illustration positions. Only the GIF's changed eye
pixels are borrowed; the installed lettering and other illustration pixels
are preserved. No additional author credit was supplied.

Each brother owns a timer, double-blink phase and independent LFSR seed.
The two initial rests are 144 and 213 updates. Each eyelid frame lasts six
updates, with a six-update open gap between the two blinks; later rests are
144..207 updates with independent sequences.

All variants are preloaded into CHR RAM. Small native vblank commands change
six background tiles per brother, plus Mario's three existing eye overlay
slots; no sprites are added. The title retains 44 sprites and at most eight
per scanline. ROM reconstruction verifies all nine combinations of the two
brothers' three eye states; hardware replays verify complete framebuffer
pixels and native selection/start transitions.

The first game now restores native graphic_data_01 before entering the lives
screen; the original intro, level-name and game-over screens share that atlas.


During the native title-to-demo handoff the title remains visible for one
setup frame after GAME_ROUTINE_INDEX becomes 2. TitleDraw owns the split
until native forced-blank loading releases G_TITLE_ACTIVE, so that final
frame uses the same correct pattern-table switch as the menu.

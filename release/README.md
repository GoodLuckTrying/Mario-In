# Current IPS patches

Sprite sheet: **metalwario64** and **superphanto**.
Testing: **cecilou**, **jroweboy** and **fanatik**.
Full attribution is in [CREDITS.txt](CREDITS.txt).

Apply one IPS patch to the matching **unmodified** NES ROM. The exact base
filenames and SHA-256 values are listed in [catalog.json](catalog.json).
[SHA256SUMS](SHA256SUMS) lists the patch hashes. Patches include the iNES/NES 2.0
header; use the exact headered input listed in the catalog.

All 17 patches here match the current installed development builds. The
Ghosts 'n Goblins patch includes the color-flashing, injury-CHR and moving-platform support repairs.
The Zelda patch also fixes the item-lift pose, and WrestleMania preserves the original deformable rope graphics while streaming every Mario/Luigi pose and fireball through native wrestler buffers. Contra fixes the base-room growth animation handoff and small Mario's crouched hitbox while retaining its existing gameplay choices (271 checks). Start updated ports from a fresh boot; older save states contain earlier graphics/RAM state.

Karnov and Rygar start as Fire Mario while retaining native health, equipment,
attacks and progression. B adds fireballs alongside the native attack. Their
current suites pass 23 and 17 checks, including assembled SMB1 movement
comparisons, native damage, scrolling projectiles and displayed graphics.
Karnov also fixes slow vertical scrolling, viewport fall deaths, life portraits
and entrance graphics. Rygar fixes the moving/weapon screen shake and floor
rebounds. Before/after failures are recorded in
[karnov-rygar-regressions.json](karnov-rygar-regressions.json).
Karnov's tall-cliff follow-up covers long falls during horizontal scrolling,
with 232-pixel moving/stationary drop tests and native map-boundary comparisons.
The actual first-stage opening ledge also passes walking/running replays and a
[22-run jump-timing sweep](karnov-opening-cliff.json) on the current ROM.

`verification/` contains the existing hash-bound test receipts for these ROMs,
and `manifests/` records their build metadata. Most receipts describe tests in the original development workspace, before the sources were reorganized. Zelda and WrestleMania were reverified here after the trailer graphics repairs (41 and 72 checks); `trailer-graphics-regressions.json` records the reproduced earlier failures. Run the included game suites for new builds. Targeted fixtures are not full
campaign clears or physical-console tests. New checks of the source-package
builds are recorded separately in `source-package-verification.json`.

This directory is committed source-tree content. No GitHub Release was created.

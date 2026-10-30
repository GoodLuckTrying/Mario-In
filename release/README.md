# Current IPS patches

Apply one IPS patch to the matching **unmodified** NES ROM. The exact base
filenames and SHA-256 values are listed in [catalog.json](catalog.json).
[SHA256SUMS](SHA256SUMS) lists the patch hashes. Patches include the iNES/NES 2.0
header; use the exact headered input listed in the catalog.

All 15 patches here match the current installed development builds. The
Ghosts 'n Goblins patch includes the color-flashing, injury-CHR and moving-platform support repairs.
Start that updated port from a fresh boot; old save states contain old RAM code.

`verification/` contains the existing hash-bound test receipts for these ROMs,
and `manifests/` records their build metadata. Those receipts describe tests
in the original development workspace, before the sources were reorganized;
run the included game suites for new builds. Targeted fixtures are not full
campaign clears or physical-console tests. New checks of the source-package
builds are recorded separately in `source-package-verification.json`.

This directory is committed source-tree content. No GitHub Release was created.

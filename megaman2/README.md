# Mario in Mega Man 2

Open `C:\nes\Mario In\Mario in Mega Man 2.nes` and start a new game. The original USA
ROM remains unchanged. NES 2.0/MMC1 support and 8 KiB work RAM are required.

- **Left/Right:** Mario movement; **B + direction:** run and shoot.
- **A:** variable-height jump; fresh A presses swim in Bubble Man's water.
- **B:** the selected native weapon/item plus an independent bouncing Mario
  fireball. Fireballs have two separate slots, cost no ammo, and use native
  buster damage/immunities even while a boss weapon is selected.
- **Up/Down:** original ladders; **Start:** original weapon menu/pause.
- Descend onto ordinary exposed enemies to defeat them and bounce. Spiked,
  shielded and protected actors retain their native danger/immunity.

Mario starts in Fire form and keeps Mega Man's energy meter, lives and E-tanks.
Damage uses the original health and knockback system. The host owns bosses,
weapon weaknesses, checkpoints, conveyors, moving platforms, ladders and room
transitions. This is Mario movement integrated into Mega Man 2; it does not
replace the original levels or reproduce SMB's terrain engine and glitches.
The rooftop intro/title and weapon acquisition portrait now show Mario.
Scene-owned CHR uploads preserve the native backgrounds, item icon, password
view and return to the weapon screen. Boss selection and ending art remain
native. The work-RAM image is packed in verified unused ROM padding and
decoded once at cold boot with rendering disabled.

Build from the workspace root:

```powershell
python megaman2/tools/build.py
python tools/verify_new_ports.py --install
```

The build verifies `C:\nes\Mega Man 2 (USA).nes` and
`C:\nes\Super Mario Bros. (World).nes`, reproduces the unmodified host payload
from the pinned [ca65 disassembly](https://github.com/plasticsmoke/megaman2-disassembly-ca65)
at `da9b91ae1793db0c736f92d96554eb724882326d`, and patches separate output files.
The baseline's header-only differences are recorded in
`../build/mm2-reference/baseline.json`. Upstream sources remain unchanged;
all injected code and hook definitions live in this project's `src/` and
`tools/` directories. ca65/ld65 come from the pinned local smb1base checkout.

SMB land motion is compared against assembled SMB1 source across 112 cases.
Emulator fixtures cover all eight opening stages, native health, shooting,
pause/resume, underwater movement and ladder handoffs. CPU fixtures cover all
12 weapons/items alongside Mario shots, original enemy/boss damage dispatch,
stomps, contact exclusions, conveyor carry, and shared CHR. Full prologue and
post-victory fixtures check the title, portrait, password view/return and
blanked scene uploads.
The 1,500-frame moving/shooting replay checks visible VRAM writes and mapper
transactions. Receipts bind these results to the exact output SHA-256.
These checks are not a complete campaign clear or proof of constant 60 Hz in
every encounter. The IPS patch is checked by reconstructing the exact ROM.

Only a passing build is installed by the verifier. A differing previous hack
is backed up under its hash before replacement. Reopen the new ROM and avoid
save states from the unmodified game or an earlier build.

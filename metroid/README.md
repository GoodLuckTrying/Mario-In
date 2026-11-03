# Mario in Metroid

Open `C:\nes\Mario In\Mario in Metroid.nes` and start a new game. The original USA ROM
remains unchanged. This native MMC1 build expands PRG ROM to 256 KiB.

- **Left/Right:** Mario movement; holding **B** also permits running.
- **A:** variable-height jump. High Jump Boots extend Mario's launch.
- **B:** the native beam/equipped attack plus an independent bouncing Mario
  fireball. Up+B aims the native beam upward while the fireball follows Mario's
  facing. Two separate fireball slots preserve all three native shot slots.
- **Select:** native missile selection; **B** fires missiles when selected.
- After collecting **Morph Ball**, **Down** changes Mario to Small Mario for
  tunnels. **Up/A** returns to full size when there is room. Small Mario keeps
  the native ball/bomb movement; collecting Bombs enables B to place bombs.
- **Start:** native pause. Descending onto suitable exposed enemies defeats
  them and bounces Mario, including floor crawlers and Mellows. Native
  invulnerable enemies and bosses retain their defenses.

Mario begins in Fire form and retains Metroid's energy/tanks, missiles,
equipment, item collection, doors, elevators and password progression. Ice,
Wave, Long Beam, Varia and Screw Attack keep their original gameplay effects.
Native knockback, lava and scripted transitions own movement while active.
High Jump Boots and Small Mario/bomb traversal intentionally adapt SMB motion
to Metroid's required equipment. Original title, story and ending art remain
native. The front pose comes from the user's supplied, permission-cleared
directional sheet; its provenance/hash is recorded in the build manifest.

Build from the workspace root:

```powershell
python metroid/tools/build.py
python tools/verify_new_ports.py --install
```

The build verifies the local USA Metroid and SMB1 ROMs, then checks the
unmodified payload reproduced from the pinned
[Metroid disassembly](https://github.com/metroidret/m1disasm) at
`efbd348d7251463d6179775fc6e901207d210610`. Header-only baseline differences
are recorded in `../build/metroid-reference/baseline.json`. WLA-DX 10.7 builds
the unchanged reference source; the injected code uses local ca65/ld65.
Host modifications live in this project's source and patch definitions,
leaving the pinned upstream checkout unchanged.

Normal-form land movement matches assembled SMB1 source in 112 cases.
Mesen fixtures exercise native health, tap/held/boot jumps, Morph Ball gating,
bombs, missiles, Ice/Wave Beam selection, stomps, side/boss damage, pause,
death and game-over/password progression. A moving/shooting replay checks
visible VRAM writes and native mapper transactions. Fault-injection CPU
checks cover NMI scratch/register preservation and interrupted MMC1 writes.
Shared missiles, elevators and item CHR remain protected from Mario's atlas.
All visible opening arrival frames use the complete front Mario pose at a
fixed height. A separate replay follows a real A-button jump onto an
initialized crawler while its native AI runs; it failed before this repair
and now reaches native defeat. Shooting checks cover upward/straight beams,
independent fireball bounces, a full native shot pool and pause. Fireballs
sweep vertical movement by pixel to honor native block-boundary collision.
Spare native gameplay object slots $0350/$03C0 hold the independent shots;
these are not beam, missile, bomb, door or player-state slots.

Verification receipts identify the exact candidate SHA-256; IPS reconstruction
and installed bytes are checked. These fixtures do not establish a complete
campaign clear or constant 60 Hz across every room. Installation backs up a
differing old hack. Reopen the ROM and start fresh instead of loading an
incompatible old save state.

Enemy drawing shares a final native renderer with objects. Mario is selected
only during native Samus drawing or the opening arrival; independent fireballs
mark their own draw calls explicitly. Enemy slot numbers never select a Mario
pose. Original OAM is compared across all six enemy slots, four species, both
facings and player forms while both fireball slots are live (96 cases). A Mesen
crowd fixture exercises five regular enemies, Mellows and simultaneous shots.

# Mario in Kid Icarus

Native NES ROM hack built from the two local ROMs in `C:\nes`. Original ROMs are left unchanged. The build expands Kid Icarus's MMC1 PRG to 256 KiB and replaces its player controller and renderer with Mario.

The separate Mario/Luigi Contra port has its own [build, controls and verification notes](contra/README.md).

The Mario/Luigi Rescue Rangers port has separate [controls, object handling and verification notes](rangers/README.md).

The Mario in Tetris port has separate [shared controls, piece interactions and verification notes](tetris/README.md).

The SMB1 Mario/Luigi port for SMB2 USA has separate [controls, hearts/fireballs and verification notes](smb2/README.md).

The Mario in Zelda port has separate [directional sprites, fireballs, Zelda items and verification notes](zelda/README.md).

The Mario in Mega Man 2 port has separate [controls, native weapons and verification notes](megaman2/README.md).

The Mario in Metroid port has separate [controls, native equipment and verification notes](metroid/README.md).

The Mario in Ghosts 'n Goblins port has separate [controls, armor, native weapons and verification notes](ghosts/README.md).

The Mario in Mike Tyson's Punch-Out!! port has separate [boxing controls, fireballs and verification notes](punchout/README.md).

## Play

Open `C:\nes\Mario in Kid Icarus.nes` in Mesen or another NES emulator supporting MMC1 and NES 2.0. Start a new game instead of loading a state made with the original game or an earlier build.

- **A:** jump; holding A changes jump height.
- **B + direction:** run. With fire power, a fresh B press also throws a fireball; two can be active.
- **Select:** equip or put away a collected hammer. While equipped, **B** swings it; successful hits consume a hammer. Put it away to use fireballs again.
- **Down:** crouch when Super or Fire Mario. Crouch jumps and momentum follow SMB1.
- **Up:** native Kid Icarus doors and room interactions.
- **Start:** native pause/menu behavior.

Mario starts small with three lives. The top HUD shows Mario's remaining lives. Enemy contact shrinks Super/Fire Mario, or kills Small Mario. Death retries the current stage while lives remain; then Kid Icarus's continue/password flow handles game over.

Hearts remain Kid Icarus currency. They also grow Small Mario and upgrade Super Mario to fire power. Collecting 100 heart units awards a life. Further hearts retain fire power and never grant star invincibility; actual star pickups still grant it. Ordinary masonry never spawns power-ups. Small Mario bumps solid pink brick metatile `$59`; Super Mario can shatter it. Other architecture and one-way platforms keep their native collision meanings.

The final stage retains the flight needed by Kid Icarus's level design and grants fire power. Falling mallets produced by Kid Icarus's transformation effect are harmless pickups. Hammer attacks retain native enemy damage and fortress statue/Centurion interactions while Mario keeps his own movement.

## Implemented

- Original SMB1 acceleration/friction branches, walking/running limits, reversal/skid behavior, subpixels, speed-dependent jump forces, variable jump height, air steering, and crouch jumps.
- Small, Super and Fire Mario; SMB1 tile art and palettes for standing, running, skidding, jumping, crouching, swimming, climbing, growth, shrink, throwing, and death.
- Stomps connected to native enemy defeat/drop handlers; two bouncing fireballs connected to native projectile/enemy checks; damage invincibility, stars, mushrooms, flowers, 1-ups and life retries.
- Descending stomps accept foot-edge landings and moving enemy heads. Adjacent enemies share the same frame's landing even after the first bounce changes Mario's velocity. A successful landing grants 16 frames of contact protection without blinking; rising side contact cannot defeat enemies.
- Camera movement up to four pixels per update, native bounds and page transitions, and background streaming adapted to running and jumping speeds.
- Player CHR, OAM and palettes are prepared together before a level becomes visible. Feet align to solid surfaces, side probes cover Mario's full height, and descending head crossings bounce Mario before enemy contact damage.
- Mario and SMB pickups use separate sprite buffers from native actors. The final hardware sprite list gives Mario priority and preserves native lyre/health pickup graphics without sharing his body slots.
- Brick bumps use the native wall-bump sound and preserve the level music.
- New spawns align Mario's wider hitbox with nearby side walls before display. This prevents an immediate opening jump from landing him inside the left wall and blocking further movement.
- Normal side rooms and fortress rooms upload walking, jumping and shrink poses. Room text, shop prices, fortress HUD and map transfers share vblank with Mario's animation; queued text takes priority and persistent HUD/map graphics refresh between pose uploads.
- Swimming and vine climbing use the SMB1 physics branches. Stock Kid Icarus has no SMB water/vines: reserved non-solid metatiles `$3E` and `$3F` enable those modes for level edits. Existing lava and columns are not reclassified.

This is a cross-game integration: Kid Icarus supplies terrain, enemies, bosses, rooms, currency, music and stage flow. It does not recreate SMB1's entire collision engine, glitch behavior, pipe/flagpole objects or level content. The original title and ending presentation are retained.

## Build

The required local bases are:

- `C:\nes\Kid Icarus (USA, Europe).nes` — SHA-256 `931786d6920dea7f9e183d907d3c4cff123197fcd14ae4066f1e817df32fd02f`
- `C:\nes\Super Mario Bros. (World).nes` — SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`

`tools/build.py` verifies both originals before applying any patch. It uses the Windows ca65/ld65 tools included in the supplied [smb1base repository](https://github.com/smbstudio/smb1base), checked out under `vendor/smb1base` at commit `46ff88f7d9e854db80bf8d50e5bf74340fcc64ce`.

```powershell
git clone https://github.com/smbstudio/smb1base.git vendor/smb1base
git -C vendor/smb1base checkout 46ff88f7d9e854db80bf8d50e5bf74340fcc64ce
python tools/build.py --install
```

Or run `build.bat` in the existing workspace. Outputs are in `dist/`; `--install` copies the ROM and IPS to `C:\nes`, preserving an existing differing build with a hash-named backup.

## Verification

```powershell
python -m pip install -r requirements.txt
python tools/verify.py
```

The suite uses the installed `C:\mesen2\Mesen.exe` in headless mode plus a 6502 instruction interpreter. `dist/verification.json` records the output ROM hash and completed checks.

- 90 movement cases / 7,200 updates compared to the original SMB1 ROM instructions, including swimming and climbing.
- Fireball free-flight position, force, and subpixels compared to SMB1 instructions in both directions.
- 34,020 tile lookups compared to the original Kid Icarus ROM across vertical, horizontal, fortress, Skyworld and final-stage adapters.
- 1,052 terrain/contact cases covering every scroll phase, ledge sides, landing speeds, embedded feet, one-way platforms, stomp crossings, adjacent enemies, bounce protection and harmless mallet pickups.
- Native first-unblank checks in every stage mode; natural descending stomps on two enemy families in all Mario forms; hammer pickup/equip/attack tests in both directions; native fortress statue removal and Centurion release.
- Hardware OAM checks with native lyre/health pickups in all Mario forms and with a simultaneous SMB pickup; extra-heart checks retain fire power and 100-heart lives without granting stars.
- Native Mesen tests for forms, pickups, fireballs, stomps, damage, retries, brick collision/PPU removal, stage loading, level transitions, camera page crossings and visible-scanline VRAM writes.
- Animation timing regressions for all three Mario forms and all seven gameplay stage modes: palette/CHR uploads must finish before visible rendering, and rendering must resume before the prerender scroll reload. Palette uploads are unrolled, duplicate scroll restoration is avoided, and pose updates yield to background streaming, brick erases and room scripts.
- A separate opening input replay uses controller input only. Most integration tests intentionally seed RAM to isolate their cases; they are not campaign clears.
- A controller-only opening replay bumps the low brick ceiling and checks that music remains active, audible and advancing afterward.
- Three controller-only opening replays jump immediately after entering the first level, then walk away, jump again and return left to regress the opening wall softlock.
- Native side-room fixtures exercise walking/jumping in all Mario forms across the three overworld engines, retain shop prices, and verify that real room-enemy contact shrinks Super/Fire Mario's graphics and collision size. Additional fortress tests retain the native room controller and check animation transfers for visible-scanline writes.

The full campaign and ending have not been completed in testing. The receipt distinguishes tested behavior from that remaining playthrough coverage.

## Source references

Mario routines were checked against [smb1base](https://github.com/smbstudio/smb1base) and the user's original SMB1 ROM. Kid Icarus integration was mapped against the matching [Computer Archeology disassembly](https://computerarcheology.com/NES/KidIcarus/). Mario and item graphics are extracted from the user's local ROM during the build; original ROMs are not included in the source project.

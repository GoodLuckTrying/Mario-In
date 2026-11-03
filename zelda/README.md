# Mario in The Legend of Zelda

Native MMC1 ROM hack built from the local USA PRG0 Zelda ROM. Open `C:\nes\Mario In\Mario in The Legend of Zelda.nes` from a fresh reset. The original ROM is untouched, and the new filename uses a separate emulator save file.

Mario is permanently **small Fire Mario**, with SMB1 side sprites and the front/back idle, walking and throwing cells from the directional sheet supplied with permission on 23 October 2026. Item-lifting poses use that front view. His cap and overalls use bright NES white so they stay visible against Zelda's sand. He keeps Zelda's four-direction movement, terrain collision, heart meter, damage, inventory, dungeons, secrets, and progression. He does not grow or shrink with hearts. The unchanged shared source and permission note are in the parent workspace's `assets/mario-directional-sheet.png` and `assets/DIRECTIONAL-SOURCE.md`. The earlier reference and its attribution remain in `assets/SOURCE.md` as historical material.

- **D-pad:** Zelda's original four-direction walking. Up/down movement alternates visibly raised left/right feet and arm swings every six moving frames, with a steady head. Releasing movement returns to the reference standing pose; attacks and item lifts retain their own poses.
- **A:** throw a directional fireball. Once a sword is collected, A also retains its native swing and full-health sword beam, so sword-dependent encounters remain playable.
- **B:** use the item equipped in Zelda's inventory. Fireballs occupy independent state and can coexist with bombs, boomerang, arrows, candle, food, flute, potion, and rod.
- **Start:** open/close the native inventory. Select an acquired B item with Left/Right.
- **Select:** native pause.

Up to two Mario fireballs can exist at once. They travel in the facing direction with a repeating fixed-point speed curve that slows near the projected bounce apex and accelerates away from it. Each stays on one straight axis. Shots animate, collide with terrain and enemies, and disappear at every screen edge; they never wrap or carry into a new room. Native enemy fire immunity and special boss requirements still apply. Friendly fireballs do not harm Mario.

All collected Zelda equipment remains functional, including sword upgrades, both boomerangs, bow/arrows, bombs, candles, flute, food, potion, rod/book, raft, ladder, rings, bracelet, keys, letter, shield, map/compass and triforce progression. Rings retain their damage reduction while Mario keeps his Fire palette. The original shield behavior remains, with Mario art in place of Link's shield-specific head graphics. Objects sharing the player sprite palette also use its white/red shades.

The ROM retains 128 KiB PRG, MMC1, 8 KiB CHR RAM and battery-backed save RAM. It uses a separate ROM filename and therefore a separate emulator save file. Zelda's native registration, save checksums and profile reload are preserved. No items are granted by the hack.

## Building and verification

Requires unchanged local originals:

- `C:\nes\Legend of Zelda, The (USA).nes`, SHA-256 `1dff2d002168e0234d206938afc5189a79eb0ec055ada12f2cd4e105f713fc7d`.
- `C:\nes\Super Mario Bros. (World).nes`, SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`.

The [complete Zelda disassembly by Aldo Núñez](https://github.com/aldonunez/zelda1-disassembly) is pinned at `50a1c869a8d8e2eb8b5b60acea325f44b4341762` in `vendor/zelda`. Every build first reproduces the original ROM payload exactly. ca65/ld65 are taken from the existing SMB1 toolchain. Changes are assembled in a private copy under `zelda/build/source`; vendor source and original ROMs remain unchanged.

From the parent workspace:

```powershell
python zelda/tools/build.py
python zelda/tools/verify.py
python zelda/tools/build.py --install
```

Installation requires the verification receipt to match the exact output SHA-256, and preserves any differing prior modified build under a hash-named backup. It installs the separate ROM, IPS, notes and verification receipt to `C:\nes`.

New fireball code occupies originally unused bank-0 space. Its small collision helper extends the native copied RAM code below `$7FC0`; private projectile state uses `$7FC0`–`$7FD0`, outside save-file blocks and before the `$7FFF` save-validity marker. Fireball patterns reuse the freed shield-head tiles in the native common-pattern upload, with rendering disabled. Zelda's weapon patterns and transparent priority sprite are preserved. Rendering claims only free OAM slots after native actors draw; it never replaces sprite zero, HUD or player records.

Verification runs assembled 6502 instructions and Mesen controller replays. It covers the four speed curves, edge overflow, terrain, two-shot limit, native enemy fire damage/immunity/death, restored room-item state, item collection/equipping, ring protection, new save registration, native save/reload, all eight B items with A fireballs/sword, pause/inventory, room transitions, all nine dungeon graphics loads, hardware sprite/palette output and PPU write timing. Vertical-walking checks reconstruct the displayed hardware sprites to verify alternating raised feet, an unchanged head, six-frame step timing, real movement and recovery of the standing pose. Native stair and room-entry rendering are checked separately.

Fixtures seed inventory, actors or positions to isolate mechanics. These checks are not a complete unassisted campaign or a physical NES playthrough. The receipt for the exact build is `dist/verification.json`.

Item lifts use separate left/right Mario halves, preserving the supplied asymmetric face instead of mirroring half the head. One-hand lifts lower the right arm; wide-item lifts retain both raised arms. The directional visual replay checks every displayed lift frame against the full authored pose in hardware OAM/CHR. Its wide pickup uses the common raft graphics; the final-dungeon Triforce of Power requires its native scene-specific patterns.

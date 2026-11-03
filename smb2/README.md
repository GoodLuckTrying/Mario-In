# SMB1 Mario and Luigi in Super Mario Bros. 2 USA

Native MMC3 ROM hack using the local USA SMB2 ROM. Open `C:\nes\Mario In\SMB1 Mario and Luigi in Super Mario Bros 2.nes` from a fresh reset. Original ROMs are unchanged.

Only **Mario and Luigi** appear on character selection. Left or Right switches between them; A confirms. Both use SMB1 sprite art, all three walking frames, walking/running acceleration, friction, reversal and air steering. Walk cadence follows speed. Jump height changes with how long A is held. SMB2's charged crouch jump remains available for its level geometry. The native engine handles terrain, moving platforms, sand, vines, jars, doors, camera movement and transitions.

SMB2's **heart meter stays intact**. Every big form has fireballs. Damage removes a native heart and grants the normal damage grace period. The last-heart threshold shrinks the player; another hit kills them. Extra hearts can therefore keep a player big through several hits. Vanilla SMB2 adds knockback when a hit leaves the player big; this port caps its horizontal speed at 1.5 pixels per frame, directed away from the impact, while retaining the upward reaction. Hearts restore health and growth, mushrooms increase maximum health as before, and lives/retries use the original game flow.

- **Left/Right:** move; hold B to run.
- **A:** jump; hold for height.
- **B, empty-handed and big:** throw a bouncing fireball. At most two can be active.
- **B with an object:** throw the object with the original SMB2 rules. Pickup and throwing take priority over firing.
- **B at a suitable object or plant:** native pickup/plucking. Objects can still be carried through jumps.
- **Down:** crouch for one second to charge a high jump, then press A. Mario/Luigi flash between regular and bright colors when the charge is ready. A full charge survives releasing Down before jumping; the ready flash continues until the charge is used. Jumping restores the regular colors. Native jar entry remains available where applicable.
- **Up/Down:** native vines and ladders. Up enters doors.
- **Start:** native pause.

Enemy-head standing and picking up enemies retain their SMB2 behavior. Player rendering follows the native object-collision pass, so standing on an enemy uses its resolved position and grounded pose. Walking, jumping off and moving-enemy carry retain the native support handling. Climbing uses two SMB frames with a stable facing and stops animating when motion stops.

Fireballs use native thrown-object damage, including boss health, cooldowns and vulnerability windows. A separate eight-pixel terrain box makes the visible ball touch the floor when it bounces; native enemy terrain boxes remain unchanged. Launches use a quieter five-frame SMB1-style chirp instead of the long native item-throw sound. Native queued effects take priority and the music channel is released when the chirp ends. Shots do not hurt their owner. A full native object pool can temporarily prevent firing. Mario has the SMB1 cream/red Fire palette; Luigi uses cream/green so the two remain distinguishable. Small forms use their regular SMB1 colors. The three player shades are refreshed after each native gameplay palette upload, preventing a delayed native buffer from leaving Fire colors on a shrunken player. Native enemy/background pattern banks and palettes remain intact.

Fireballs disappear when they leave the horizontal edges of a scrolling room. They wrap horizontally only in the native single-screen vertical rooms where the player and enemies also wrap.
They disappear at the top and bottom of the viewport in every room; vertical scrolling and world-page crossings never make a shot reappear at the opposite edge.

## Build

Requires the unchanged local files:

- `C:\nes\Super Mario Bros. 2 (USA).nes` — SHA-256 `41300bc4942a8a4f9b53148b404dd5cae3dd708ebdd9b617888d290a51a83e43`
- `C:\nes\Super Mario Bros. (World).nes` — SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`

The [SMB2 disassembly](https://github.com/Xkeeper0/smb2) is pinned at `b73415e1953d7fdffd4957d5fb43fa7a13844c1c` under `vendor/smb2`. Its included asm6f assembler builds a private source copy in `smb2/build/source`. The original reference must reproduce every PRG and CHR byte from the local SMB2 ROM; only the local ROM's NES 2.0 header differs from the reference iNES header. Graphics are extracted from the local SMB1 ROM.

From the parent workspace:

```powershell
python smb2/tools/build.py
python smb2/tools/verify.py
python smb2/tools/build.py --install
```

Installation requires a passing verification receipt matching the exact ROM hash. It copies a separate ROM, IPS patch, notes and receipt to `C:\nes` and backs up any differing prior modified build. The cartridge retains 128 KiB PRG, MMC3 and 8 KiB RAM, and expands CHR to 256 KiB. Added controls occupy the originally empty second half of PRG bank pair 6/7. Player pose banks are selected through the native vblank uploader; no visible-scanline pattern uploads are added.

## Verification

The hash-bound receipt is `dist/verification.json`. Checks execute assembled 6502 code and run isolated Mesen replays with hardware CHR, palette, OAM and PPU timing observations. Coverage includes differential SMB1 horizontal physics, signed gravity/collision velocities, held/released jumps, two-shot limits, heart damage/shrink/healing, retries, both character choices, native carrying/throws, doors and all seven world openings. Additional replays cover enemy-head support, movement, jumping off, lifting and moving-enemy carry; all three walk frames; released/held-Down charged jumps; stable up/down climbing in both facings; and exact fireball floor contact. Assembled CPU checks cover bounded directional hurt impulses and the short fireball sound's register writes, duration and native sound priority.

Palette regressions check actual PPU colors after enemy damage and heart recovery. A real shrink followed by a delayed native palette-buffer upload also verifies that regular Small colors persist for both brothers, with PPU writes restricted to blanking. Charged-jump replays check visible regular/bright palette alternation for both brothers and sizes, no premature flash during a partial charge, and restored colors after jumping.

Interaction fixtures seed positions or actors to isolate a mechanic, then run the native engine with controller input. These checks are not a complete unassisted campaign or physical hardware playthrough. Boss vulnerability and native item puzzles still apply.

Source physics correction (23 October 2026): normal walking/jumping now integrates signed position fractions and full 8.8 vertical velocity directly, applying SMB1 gravity after the old velocity moves the character. Native collision changes are imported before the position step, and moving supports contribute their native displacement without permanently changing Mario's speed. Scripted states, climbing, lifting and deep quicksand keep their native integrator. Heart health, charged jumps, carrying/throwing and native room behavior are retained. Expanded comparisons cover 480 cases and 61,768 updates against assembled SMB1base source. Live Mario/Luigi tap and held jumps reproduce 24/64-pixel apexes.

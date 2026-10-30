# Mario and Luigi in Snake Rattle 'n' Roll

A native NES port built from the local USA Snake Rattle 'n' Roll ROM and SMB1 graphics. The original ROM is not modified.

Load `C:/nes/Mario and Luigi in Snake Rattle n Roll.nes` from a fresh reset. Existing Snake save states are incompatible with the added character state and WRAM.

Select the original one- or two-player mode. Player 1 is Mario; player 2 is Luigi.

Controls:
- D-pad: the game's original isometric movement and momentum.
- A: Mario-style jump; hold for a higher jump. The Moon level retains its special low gravity.
- B: use the original tongue to collect Pibbles and attack. With Fire Flower power, the same press also throws a fireball in the last movement direction.
- Start: original pause behavior.

Eat **two Pibbles to grow**, then **two more for Fire Flower power**. Every successfully eaten Pibble counts once, regardless of its color or the character's weight. Each player earns upgrades independently. Collecting a 1-Up, entering/leaving a bonus room, or changing levels does not remove an upgrade. Fire Flower stays capped after more food. Powered damage shrinks the character, resets progress toward the next upgrade, and gives temporary protection while retaining the weight needed for the exit scales. A small character loses a life when damaged. New lives start small. Each player can have two fireballs active.

Pibbles must be caught with the tongue; touching them does not collect them. The original food, weight, exit scales, collectibles, enemy vulnerability rules, lives, music, scrolling, and all eleven stages remain native. Snake body segments are hidden; their native weight/progression state is retained. Original stompable enemies retain their stomp interactions with a stronger bounce. Fireballs use the native attack damage, boss HP, scoring, and defeat paths. Fireballs bounce in the vertical world axis about their launch plane.

Pibbles, flipping manhole covers, exit doors, scales, elevators, NPCs, and native death particles retain their original tile graphics. All eight original CHR banks remain available at their native bank numbers, including the music and room data read through the PPU. Two additional physical sprite banks buffer the new user-supplied directional sheet. Transfers use at most 64 bytes per eligible vblank, skip resident chunks, and yield to native terrain, music commands, background animation, and temporary data-bank reads. The asset copy permits a bank-safe native lag interrupt, and body changes use a complete alternate DMA page prepared outside vblank. The final scroll restore therefore retains its pre-render deadline. Mario combines separate clothing and skin layers; all five canonical views have idle, three walking frames and a jumping frame. The supplied canonical side/diagonal cells face left and are mirrored for rightward movement. Each player keeps independent direction and power. See `../assets/DIRECTIONAL-SOURCE.md` for the source hash and permission note. Fire Mario and Fire Luigi use the exact SMB1 pixel colors ($37 cream, $27 skin, $16 red). As requested, the shared red, yellow, and white sprite shades are adjusted to match; Pibbles and enemies sharing those shades also change color. Other palette entries retain their native values. The manhole lookup safely returns when a collision tile has no listed entry; valid listed manholes retain their native contents and room transitions.

Build: `python snake/tools/build.py` from the parent workspace. Verify both ports: `python tools/verify_ports.py`. Install after verification: `python snake/tools/build.py --install`.

Requires the exact original ROMs in `C:/nes`; SHA-256 values are checked by the builder. `dist/Mario and Luigi in Snake Rattle n Roll.ips` reconstructs the output from the original Snake ROM. The expanded ROM uses MMC1 with 128 KiB PRG, 64 KiB CHR RAM, and 8 KiB WRAM; all original CHR bytes remain intact in PRG and are copied to the original eight RAM banks at boot, including their native room/audio code. Source requires the bundled cc65 tools, Python, py65, and Mesen for integration tests.

Left/right mirroring changes immediately in OAM. Changes of view, pose, or form wait for a complete graphics commit; their latency depends on resident chunks and the native vblank workload. Collision and movement remain immediate.

Verification covers actual assembled 6502 routines, cold boot, solo/co-op, tongue-only meals of different colors, two meals per upgrade, native 1-Up collection retaining Fire Flower, bonus-room entry/return preserving power, valid/missing manhole lookups, independent forms and fireball slots, controller-fired native boss HP/defeat fixtures, displayed native sprite patterns, exact Fire Mario colors and approved shared shades, cover/door animations across all player-form pairs and three stage graphics sets, isometric projectile projection, stage openings on all eleven stages, native music/scenery/room-code preservation, sprite DMA timing, and IPS reconstruction. Motion regressions drive walking, turns, jumps, and attacks in all forms across eleven stages and check the final horizontal/vertical scroll reload deadlines; a separate controller fixture checks both brothers' actual OAM facing in eight directions, with captured rendered frames. It is not a full unassisted campaign clear or a hardware test. See `dist/verification.json` for the tested ROM hash and results.

Research references:
- https://tasvideos.org/GameResources/NES/SnakeRattleNRoll
- https://unaryheap.blogspot.com/2016/08/snake-rock-n-roll-introduction.html

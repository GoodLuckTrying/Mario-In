# Mario in Tetris

Native NES ROM hack of the user's Nintendo USA Tetris, with small Mario inside the original 10 by 20 playfield. Open `C:\nes\Mario In\Mario in Tetris.nes` and start a new game. The original ROM is unchanged.

After the title, choose **Solo** or **VS**. VS opens a second menu with **VS CPU** and **VS HUMAN**. Use the D-pad to select, A or Start to confirm, and B to return. Solo then opens the original A-Type/B-Type and music menus. VS uses A-Type's board, with the original starting-level menu.

On the first **Solo / VS** screen, **hold Select and press Start** to enter the hidden **Auto-Classic** mode. Choose a starting level normally. The HUD reads **AUTO**. The CPU plays A-Type Tetris by itself, building lines and favoring available Tetrises. Mario is absent, and the CPU never targets him or uses VS climbability restrictions. Both controllers' piece controls are ignored. Start pauses/resumes, Select toggles the preview, and A+B+Select+Start returns to the menus.

Auto-Classic keeps native scoring, line clears, starting-level thresholds and top-out. It holds the piece while evaluating placements and steering at the top, then drops it through native controls and gravity. A failed plan plays the piece from its current position, and normal Tetris game-over rules apply. After game over, Start returns to level selection for another attempt.

## Solo

One NES controller controls both Mario and Tetris simultaneously:

- **Left / Right:** move Mario with SMB1 acceleration and friction, and move the falling piece with Tetris's normal repeat timing.
- **A:** jump as Mario and rotate the piece clockwise. Hold A for a higher jump.
- **B:** rotate the piece counterclockwise. Holding B also lets Mario run.
- **Down:** normal Tetris soft drop.
- **Start:** native pause/resume. Both Mario and the falling piece freeze.
- **Select:** native next-piece preview toggle.
- **A + B + Select + Start:** native return to the menus.

Mario stays inside the well. The falling piece has solid sides: Mario's horizontal movement stops at its occupied cells. Moving or rotating a piece into him pushes him sideways. If a horizontal push is blocked by the well or settled terrain, that piece movement is rejected; Mario is not pushed through it or crushed. Shape gaps remain empty. Land on an occupied cell from above to destroy the whole falling piece and bounce. The next piece then spawns normally. Once the piece locks into the board, its cells become solid terrain: Mario can stand on them, and jumping into their underside breaks the cells directly above his head. His upward movement stops at the hit. Other cells and the layer above remain intact; the well's borders cannot be broken. Normal line clears also remove settled cells.

A descending piece hitting Mario's head kills him. Horizontal moves and rotations resolve their side pushes before the next descent. Settled cells are safe to hit from below. His death animation finishes, then the native game-over curtain and score/menu flow take over. Each game is one attempt; there are no extra Mario lives or power-ups. Normal Tetris top-out still ends the game. Stomps and head breaks do not add line-clear points.

A-Type and B-Type retain the original scoring, piece generation, gravity speeds, line clears, menus, music and B-Type completion. Mario spawns above B-Type's initial garbage pile. The original title and ending graphics are retained.

## VS CPU and VS HUMAN

Controller 1 controls Mario: Left/Right move, A jumps (hold for height), and B runs. Those inputs no longer move or rotate Tetris pieces. In VS HUMAN, controller 2 controls the pieces: Left/Right move, A/B rotate, and Down soft-drops. In VS CPU, the computer owns those piece controls and ignores controller 2. Controller 1's Start pauses both sides, Select toggles the next-piece preview, and A+B+Select+Start returns to the menus.

Mario wins a round by jumping or bouncing out through the **top of the well**, with his feet reaching **8 pixels above the top edge**. Simply being raised onto the top row does not win; he must leave upward. The board clears, Mario returns to the floor, and the next round starts one level beyond the **current** level. Score, total lines, and piece statistics carry over. Every additional ten lines also raises the VS level. For example, if the CPU raises level 0 to 1 before Mario escapes, that escape begins level 2. An escape during line scoring waits for that scoring to finish so the earned level is preserved. VS levels stop at 99.

The round-clear screen lists the escaped level, Tetris level gains during that round, next level, cumulative lines, and cumulative score. Both players freeze while it is displayed. Press A or Start after the brief reading pause to continue, or wait about three seconds for automatic continuation. Continuing with Start does not pause the new round, and continuing with A does not immediately jump Mario.

At levels **0 through 9**, the CPU favors clean stacks, an open right-hand Tetris well, and four-line clears over smaller clears. Starting at **level 10**, its placement score increasingly favors Mario's column, and it actively follows him while the piece falls. It changes direction when Mario changes sides, diverts if direct pursuit is blocked, and attempts to sidestep an approaching stomp. Tracking decisions become more frequent as levels increase: every 30 updates at level 10, 21 at level 19, 11 at level 29, and six from level 34 onward. Initial placement pressure grows through level 33. Moves are still checked for legal geometry and a climbable resulting stack; a cornered piece can still be stomped. Piece selection, steering, rotation, locking, scoring, and line-clear animation run through the native engine, without teleporting a falling piece back to spawn.

VS fairness safeguards:

- New pieces have a reaction interval. The CPU also pauses for 30 updates after committing to its target. Head contacts are harmless during the spawn warning; stomps still work.
- Gravity and soft drop cannot descend faster than one row per six updates, including at the highest levels.
- The CPU rejects placements that create a new main-stack cliff taller than 32 pixels. It checks the board after any proposed line clear too, including pits hidden underneath a completed row. The narrow right-edge Tetris well is exempt from that surface test.
- Existing cliffs created by Mario's head breaks can be left unchanged or repaired; they cannot force every future CPU plan to fail. A committed falling piece keeps descending when terrain changes, then receives another safety check before locking. Pursuit and dodge moves also pass the landing and post-clear safety checks. Removing support during locking resumes gravity.
- If no safe CPU placement exists, that piece is discarded. A blocked spawn yields another piece instead of causing a Tetris top-out loss. Mario can still lose to an avoidable falling-piece head hit.

Search work is spread across frames. Deterministic CPU replays at levels 0, 9, 19, and 29 check that Mario continues updating every frame and that background/CHR writes remain in vblank.

## Build

Required local originals:

- `C:\nes\Tetris (USA).nes` — SHA-256 `ddb876c302cfd4ee19fabff8e3ede0b6801ded70c49980d1682a32d352953082`
- `C:\nes\Super Mario Bros. (World).nes` — SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`

The [Tetris disassembly](https://github.com/CelestialAmber/TetrisNESDisasm) is pinned to `94581c0306fa0009fe11fde48222875549d15b8b` under `vendor/tetris-nes`. Its reference build must reproduce every original PRG and CHR byte. ca65/ld65 come from the existing `vendor/smb1base/tools/Windows/cc65/bin` directory. Mario graphics come from the local SMB1 ROM.

From the parent workspace:

```powershell
python tetris/tools/native.py
python tetris/tools/build.py
python tetris/tools/verify.py
python tetris/tools/build.py --install
```

Outputs are in `tetris/dist/`. Installation requires a successful verification receipt for that exact ROM. It copies a separately named ROM, IPS patch and notes to `C:\nes`, backing up a differing previous build. The original Tetris and SMB1 ROMs are never modified.

The cartridge retains MMC1 and 32 KiB native PRG, adds 8 KiB work RAM, and expands CHR to 128 KiB. The added code loads into work RAM at boot. Mario uses a separate sprite palette and reserved tiles in duplicated gameplay sprite banks; the background pattern bank remains identical to Tetris. Pose-bank changes occur during vblank. The native MMC1 reset opcode is preserved.

## Verification

`dist/verification.json` records the exact tested ROM hash and individual checks. Tests use `C:\mesen2\Mesen.exe`, Python and `py65` from the workspace requirements.

- 42,176 independent CPU cases cover locked-cell lookup, body probes, both walls, held/released jumps, every mino in all 19 orientations, empty shape corners, stomp priority, settled head breaks, redraw coalescing, Solo's permanent roof, VS top exits, and finite death. They also cover live-piece side blocking and pushing, wall pins, legal CPU paths, Tetris priority, active tracking, evasive moves, blocked pursuit, post-clear safety, spawn recovery, reaction timing, and permanent round progress. Auto-Classic cases check legal placements, independence from Mario and level-based targeting, available Tetrises, native scoring and level thresholds, and real top-out without discarded pieces.
- A controller replay verifies shared movement, jumps, both rotation directions, actual SMB1 sprite CHR, Mario's palette, unchanged background CHR and vblank bank changes.
- Native emulator fixtures cover a controller jump onto a falling piece, bounce/removal/next spawn, a falling head hit and game over, locking and jumping onto settled blocks, line clearing with its original score, pause/resume, fresh-game resets, all B-Type garbage heights, B-Type completion and attract-mode return.
- Controller head breaks cover all eight pixel alignments, a newly locked piece and an already busy board redraw. They check safe upward collision, exact cell removal, unchanged surrounding/upper cells and the hardware nametable. The head-break regression fails on the previous ROM.
- Original-versus-modified piece/board traces at levels 0, 9, 19 and 29 check normal movement, rotation, soft drop, gravity and locking while Mario is sheltered to isolate the native engine.
- VS controller replays cover main/submenu rendering and Back navigation, both controller roles, a normal CPU run earning Tetrises, higher-level CPU frame budgets, an actual CPU four-line placement and level-up, pause, death, top-edge jumps, pending scoring during an exit, board clearing, and another line-based level after an escape.
- Additional replays check both walking directions against a live piece, pushes from both sides, rotation pushes, a wall pin, the higher escape threshold, every clear-screen value, A/Start/automatic continuation, separated menu arrows, tracking at levels 9/10/19/29/99, obstacle diversion, an open-space dodge, and a successful stomp against a cornered CPU. They check update timing and vblank transfers as well as resulting positions.
- Auto-Classic controller replays check held and simultaneous Select+Start entry, exclusion from the VS submenu and ordinary menu input, all seven tiles of the AUTO/VS CPU/VS P2 labels, absent Mario sprites, unassisted line-clearing runs at levels 0/19/29, native Tetrises and level progression, blocked-spawn game over, pause/resume and returning to Solo through reset. Runtime checks include frame timing and vblank transfers.
- Original hashes, the exact native reference, unmodified PRG outside documented changes, work-RAM code bounds and exact IPS reconstruction are checked.

Most interaction fixtures seed a board or piece position and then run native code with controller inputs. These checks are not an unassisted complete game or a physical NES hardware test.

Source physics correction (23 October 2026): Mario keeps momentum and facing with neutral airborne input, selects his jump before horizontal acceleration, and integrates the source game's vertical fractions and falling limit in the original order. Floor contact resolves at the feet in the landing update. Shared piece controls, safe settled-block head breaks, piece pushes/stomps and all modes remain available. Expanded comparisons cover 120 cases and 15,442 updates against assembled SMB1base source. A live replay checks top-speed air coasting and a separate stationary jump's fractional terminal descent.

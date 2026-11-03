# Mario and Luigi in Rescue Rangers

Native NES ROM hack of the first **Chip 'n Dale: Rescue Rangers (USA)**. Mario replaces Chip; Luigi replaces Dale in the original two-player mode. Original ROMs and the existing Kid Icarus/Contra ports are left unchanged.

Open `C:\nes\Mario In\Mario and Luigi in Rescue Rangers.nes` in Mesen or an emulator supporting NES 2.0 MMC1 with 8 KiB work RAM. Start a new game; old save states contain different code and RAM layouts.

## Controls

- **D-pad:** move. **B + direction:** run with SMB1 acceleration, braking and air steering.
- **A:** jump; holding A changes height. Jumping works while carrying an object.
- **B:** pick up or throw a native object. **Up + B:** throw upward. A carried object takes priority over fireballs.
- **B with empty hands in Fire form:** throw a bouncing fireball. Each player can have two active.
- **Down:** crouch when tall. Hold Down with a suitable box to hide inside it and retain its native contact defense.
- **Down + A:** drop through a one-way background platform.
- **Doorways:** walk into the opening to enter its native destination room.
- **Start:** native pause/menu behavior. Choose **2 Players** on the title screen for Mario and Luigi together.

Crates, apples, heavy boxes, object-specific wall interactions, and picking up/throwing the other player remain native game mechanics. Heavy metal boxes retain their horizontal wall-smash action while held; Up + B can throw them upward. Native scripted co-op tosses keep their original brief motion before SMB control resumes.

Throws use the native object release and damage routines without applying a second player physics update. Horizontal throws work at screen edges and while airborne, follow the current facing direction, and have a short recatch delay. Picking up an object while moving does not throw it on the same B press.

Background boxes in the map create carried objects through the native pickup routine. Pickup reach accounts for Mario's wider body on both sides, including the two boxes on the high starting platform. Holding B while running into a background box picks it up once; release and press B again to throw it. Level initialization clears every unused object slot correctly, and fireball collision proxies prefer high object slots so native box slots remain available.

## Powers and combat

Players start small and receive powers by collecting the level's native flower collectibles. The first flower gives mushroom growth; the next upgrades a tall character to Fire form. Further flowers retain Fire form. Native flower counts, scoring and extra-life thresholds still work. No free mushroom/flower supplies spawn at level entrances. Each player's power is independent. The native HUD heart row shows one heart for Small, two for Super, and three for Fire; these indicate form, rather than three independent hits.

Enemy contact shrinks tall forms with temporary invulnerability. Small form loses a life and uses the native retry flow. Descending onto an ordinary enemy defeats it and bounces the player. Adjacent enemies can share the landing, with a short period of contact protection after a stomp. Electric Sparkies remain harmful and cannot be stomped; all three native variants keep their native state and damage the player on landing. Electrical terrain also retains its damage behavior. Bosses and projectiles retain their native contact rules.

Fireballs use the native thrown-object damage dispatcher, including boss health, vulnerability windows, hit cooldowns and defeat/level-clear behavior. Invisible native object slots carry the collision data; they do not add crate graphics or make the fireballs solid platforms. A full native object pool can temporarily prevent another fireball from spawning. Carried objects remain usable in every form and retain their own native damage rules.

Rescue Rangers supplies the levels, terrain, movable objects, enemies, bosses, music, menus, scoring, bonus items and stage flow. Mario art is extracted from the local SMB1 ROM and packed into the original player CHR slots. This does not add SMB levels, question blocks, pipes, flagpoles or star power. Title/cutscene artwork remains Rescue Rangers artwork. NES sprite limits still apply.

Native sprite palette RAM is preserved. Apples and enemies keep their original red/gray palettes; Mario/Luigi use separate green/yellow palette slots in the hardware copy. Single-player mode chooses the less-used slot. When native sprites also need a reserved slot, they share the remaining green/yellow slot in single player or the native gray palette in two-player mode. This is the four-sprite-palette hardware limit; red apples and the main enemy palettes remain exact.

Terrain probes outside the top of the viewport return empty space instead of wrapping into the bottom collision row. Native probes left of the world also return empty space, preventing stale terrain coordinates from reporting a phantom hazard at the top-left corner. Actual hazard tiles retain their damage behavior. Native doorway tiles are reachable entry volumes, so walking through the rooftop satellite doorway triggers the original room header and transition. Entry preserves each player's form, clears custom fireballs, and releases an outside carried crate as the original game does.

## Performance

The controller now copies state in blocks, loads only the animation fields needed for drawing, copies the used native sprite prefix once, and omits transparent tiles above Small Mario/Luigi. Native palette use is recorded during that sprite copy. Horizontal movement tests the final position and backs out wall or object penetration; 8,352 boundary cases cover pixel alignment and world-page crossings.

In a fixed 400-video-frame opening replay, Small Mario completes 395 movement updates, compared with 227 in the preceding build. Average game-update work drops from about 29,739 to 20,000 CPU cycles. Fire-form co-op drops from about 43,805 to 33,000 cycles per update. Tall forms and busy two-player scenes can still slow down on the NES CPU; this is not a claim of a locked 60 fps throughout the game.

## Build

Required unchanged local originals:

- `C:\nes\Chip 'n Dale - Rescue Rangers (USA).nes` — SHA-256 `8d5e3d9ce20fa0a61b23e93dbc975606803f2d5e7a264514b02b96f832a63181`
- `C:\nes\Super Mario Bros. (World).nes` — SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`

From the parent workspace:

```powershell
python rangers/tools/build.py
python rangers/tools/verify.py
python rangers/tools/build.py --install
```

The assembler/linker are the Windows ca65/ld65 tools in the user's supplied [smb1base repository](https://github.com/smbstudio/smb1base), already under `vendor/smb1base`. The integration was mapped directly against the matching local Rescue Rangers ROM with a 6502 disassembler and bounded Mesen tests. The build verifies base hashes, expands PRG to 256 KiB, loads the new controller into bank-independent work RAM, and preserves CHR banking for the backgrounds and native objects.

Outputs are in `rangers/dist/`. Installation uses separate filenames and retains a differing previous build in a hash-named backup.

## Verification and coverage

`dist/verification.json` records the exact tested ROM hash and individual results. Tests include:

- 108 SMB1 movement comparisons, totaling 8,640 instruction-executed updates, across both controllers and all three forms.
- Controller-driven opening movement, crate pickup/throwing, and screen scrolling; a cold-boot controller-only route jumps onto the upper platform and lifts a box from its right side without seeding player or map RAM. Native collectible progression and absence of free entrance supplies are covered for both players.
- All 11 native stage openings, hardware sprite DMA, and vblank-only terrain/palette transfers.
- Picking up, jumping with and horizontally/upward throwing native objects in both controllers and all forms, including moving pickups, airborne and screen-edge throws, heavy-box behavior and co-op player pickup/tossing.
- Ordinary/adjacent enemy stomps, body-sized contact checks, shrink, small-form death and retries. Explicit descending-contact tests cover all three Sparky variants and electrical terrain for both controllers in every form.
- Landing, full-speed wall contact, low-ceiling jumps, one-way drop-throughs, and standing on movable objects.
- Top-left corner jumps in every form, 1,525 wrapped viewport probes, and a native stale-coordinate phantom-hazard regression. Collectible tests also confirm that real hazards still cause damage.
- Fireball kills, independent projectile limits, and native boss damage through all five hit/cooldown cycles into the native defeat/clear sequence.
- Native room transitions, original ROM hashes and exact IPS reconstruction. Forty-eight real satellite-doorway approaches cover both players, every form, walking/running, solo/co-op and carrying a crate. The native loader loads the untouched destination approach; controller input must reach the doorway and invoke the original room trigger.
- Actual opening upper-platform and lower stacked background-box pickups: both sides, both controllers, all forms, standing and approaching with B already held. The map boxes themselves remain unchanged until the native pickup removes them.
- Six measured frame-work regressions across all forms in single-player and co-op, plus full 64-sprite output-capacity checks.
- Original enemy/apple colors in every stage and in two-player mode.

Most fixtures deliberately seed RAM to isolate mechanics. The boss fixture holds the target in the attack plane while retaining its native health and defeat logic. These checks are not an unassisted campaign clear; the full campaign and ending have not been completed in testing.

## Source physics corrections (23 October 2026)

Crouch jumps retain the short body throughout flight. Grounded Down+direction follows SMB1's input filter, with native object pickup/throws and directional actions retained. Expanded source comparisons cover 720 cases and 92,652 updates across both brothers and all forms. Live controller replays also check the airborne crouching body.

Sprite rows share their coordinate calculations, native sprite copies use one precomputed bound, and state transfers use unrolled copies in private cartridge RAM. All native palette, object and 64-sprite capacity checks remain required. The measured opening Fire replay improved from 354 to 369 updates per 400 video frames; Fire co-op improved from 202 to 207, and Small solo measured 396. Heavy co-op remains near 31 updates per second in this fixture. The optimization reduces work but does not eliminate all NES slowdown.

# Mario and Luigi in WWF WrestleMania

Load `C:/nes/Mario and Luigi in WWF WrestleMania.nes` from a fresh reset. The original USA WrestleMania and SMB1 ROMs remain untouched. Previous original-game save states do not initialize this port's additional graphics/state.

Human players choose Mario or Luigi. In one-player Standard mode, the opponent carousel offers all six original wrestlers, with their original portraits, names, graphics, AI, and wrestling moves. CPU opponents in tournaments also use the original wrestlers. All eight original game modes, including two-player Standard and party tournaments, remain available. Human participants may choose the same brother.

Controls retain the original wrestling behavior:

- D-pad: move around the ring.
- A: the native kick and its directional combinations.
- B: the native punch and its directional combinations, plus a bouncing fireball.
- Hold Down + A beside a fallen opponent: pin. Both brothers use this combination. Mario/Luigi align with the fallen body and hold still for the referee's three-count; the original kick-out rules remain active.
- Original running, rope, jumping, grappling and pin combinations remain in the native engine.
- Start: pause and resume.

Both brothers always have fireball power; no item is required, and taking damage does not remove it. Each human wrestler has two independent projectile slots and a short firing cooldown. Fireballs damage the opponent's native energy bar, cause legal hurt/knockdown states, and expire at the screen boundaries. Fatal fireball damage immediately enters the native down state, leaving the opponent available for a pin. Subsequent fireballs do not restart that down animation. The original game handles energy regeneration separately from recovery and kick-outs; gaining energy does not itself make a fallen wrestler get up. Pins still decide matches. Fireballs cannot be thrown while pinned or performing a pin. Original CPU wrestlers retain their own attacks.

One-player Standard is one bout, and intentionally returns through the original intro/title after the result. Tournament advances to the next opponent.

Fireball damage follows the engine's separate actor and health-bar ordering: the defender's body reacts and its matching on-screen energy bar decreases. The shooter's own energy stays unchanged. Character selection uses the original unrolled portrait/text upload cadence and page-aligned source data so its raster splits finish within each video frame, including both carousel wrap directions and the original opponent roster. The confirmed human portrait, colors and stats stay visible throughout its outgoing slide before the CPU opponent selector appears.

Mario and Luigi use SMB1 Fire colors and bodies, with the established Kung Fu punch/kick art adapted to the ring. Front, back and diagonal movement use the user's newly supplied directional sheet, with distinct moving feet. See `../assets/DIRECTIONAL-SOURCE.md` for the source hash and permission note. Side walking, airborne moves, kicks, punches, grapples and knockdowns have corresponding poses. Ordinary flinches use an upright guard pose on the physical body anchor, avoiding the original wrestlers' artwork offsets that made Mario jump sideways/upward. Native wrestling movement/physics and energy replace the SMB growth/heart system for this port.

Pose selection follows each body's resolved native action. WrestleMania processes the two bodies on alternating frames; pending Up/Down requests must not be mistaken for airborne moves before their script runs. Held walking directions remain consistent between fractional movement steps, stopping uses a still idle pose, and the supplied diagonal art is mirrored to match native facing. A two-controller regression checks 1,440 movement/idle/facing cases across all eight directions and verifies directional CHR in hardware after the HUD/ring split. The same replay reproduces the false jump pose on the prior ROM.

Original CPU wrestler graphics continue to stream into their native pattern slots. All Mario/Luigi body poses and fireballs reuse the human's native 20-tile packet and three-buffer rotation. Each human packet holds twelve body tiles and two fireball tiles; the remaining six native cells are preserved. The complete ring and deformable rope pattern range `$1000`–`$1C2F` stays byte-for-byte native, including the `$83`–`$C2` tiles used when ropes bend. Only the human's unused native tile-byte copies and redundant body OAM copy are skipped; native pose geometry, physics and CPU graphics stay active. Body and fireball OAM are prepared outside the timed HUD section. The short overlay copy preserves original CPU bodies/shadows, ring bonuses and referee counts, and the original HUD split remains on its measured scanlines.

The ROM uses 8 KiB of added work RAM for prepared OAM and per-player streaming state. Reload from a fresh reset; earlier save states do not contain this state.

Build from the parent workspace:

```
python wwf/tools/build.py
python wwf/tools/verify.py
python wwf/tools/build.py --install
```

The builder checks the exact original ROM SHA-256 values, creates a separate 256 KiB AxROM ROM and IPS patch, and only installs an output with a matching successful verification receipt. It backs up a differing prior modified ROM before replacing it. Sources require the workspace's bundled ca65/ld65 tools, Python, Pillow, py65, and `C:/mesen2/Mesen.exe`.

Verification checks original ROM preservation, exact IPS reconstruction, all original wrestler portraits/stat data and their native graphics streaming, assembled 6502 fireball limits/bounds/damage against all six opponents, packed sprite pixel reconstruction, actual controller selection/movement/front/back animations/melee/fireballs/pause, native opponent AI and energy damage for all six originals, simultaneous two-player attacks, private RAM isolation, PPU write safety, frame cadence and native win/loss/referee/menu transitions. Every match replay checks the first HUD reveal, every HUD/ring split and preservation of original CPU body/shadow OAM. Full controller matches start at full energy and proceed through fireball defeat, an unattended knockdown, actual Down+A input, native referee counts and the correct victory for all six originals and both controllers/brothers. Those CPU pin replays suppress AI input without seeding health, positions, defeat flags or referee counts; separate combat replays keep AI active. Other combat/end-of-match tests include deterministic fixtures. This is not an unassisted tournament clear or a physical-console test; see `dist/verification.json` for the exact tested ROM hash.

Selection regressions also measure the raster position of the original split points over extended one- and two-player carousel replays, and compare the displayed portrait pixels, stats and palettes throughout outgoing slides. Damage regressions physically fire from both controllers and use close-range native melee, checking both health bytes and the actual HUD energy tiles to confirm that only the defender loses health. Additional replays check held pins at both ropes for both controllers, injury anchors for both brothers, a complete match against unfrozen Bam Bam AI, and post-victory Standard/Tournament flows into a second playable match. The rope-pin cases use position-only fixtures after a real controller defeat; the post-victory cases use referee fixtures to isolate scene handling. Static HUD font/ring/deformable rope patterns are compared to a fresh boot of the exact original ROM, excluding native generated participant-name glyphs and the reserved split marker.

The unfrozen AI replay follows the displayed fallen body when approaching for a pin and holds Down+A within its visible range. It allows up to 4,400 match frames for legal recovery and repeated kick-outs; the other pin replays retain their 2,200-frame bounds. No energy, defeat, referee, or winner state is seeded for that live match.

Free human bodies are restored to the native perspective ring bounds after native updates. The original movement validator rejects every step from an already invalid depth, including attempts to walk inward. A bottom-rope pin between different native body heights could leave the pinner at depth 208 after a kick-out, below the maximum legal depth of 199. Active pins, native pinned bodies and original rope/climbing scripts keep their temporary coordinates; normalization runs after those states release the body. Fireballs also respect the original rope/climbing immunity so they cannot replace those scripts with a hurt action halfway through their cleanup.

Boundary regressions cover Mario and Luigi on both controllers, both axes and all 256 depth bytes. Native recovery replays start with full energy, defeat the other player through actual fireball inputs, place the players near the bottom rope using a coordinate-only fixture, enter a real Down+A pin, and select the RNG outcome for a legal native Up kick-out. They require the released pinner to walk back into the ring and take damage from subsequent native controller kicks. Complete HUD/portrait patterns and native raster phases are checked during these transitions. Separate live-opponent stress replays exercise walking and hits near the rope. The supplied screenshot's HUD corruption was not reproduced in Mesen during the investigated cases.

The earlier front-sprite reference credited CursedMario (`assets/SOURCE.md`); it is retained as a historical source. Current directional art comes from the later user-supplied sheet, with permission to use it; no author name was supplied.

The trailer rope regression replays the recorded movement/combat sequence for both brothers, checks every deformable rope pattern on every displayed frame, and requires actual deformed rope tiles to appear. A shared hardware oracle checks complete body and fireball patterns after the native HUD/ring split in every match replay, in addition to exact raster timing.

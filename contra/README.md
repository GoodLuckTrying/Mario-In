# Mario and Luigi in Contra

Native NES hack of the local US Contra ROM. Player 1 is Mario; player 2 is Luigi, with shared Mario character art and separate red/green palettes. Both players have independent movement, power, animation, damage and fireballs.

Open `C:\nes\Mario In\Mario and Luigi in Contra.nes` in Mesen or an emulator supporting NES 2.0 UxROM with 8 KiB of work RAM. Reopen the ROM and start a new game when updating; save states contain the previous code. Select 2 players on Contra's original menu for Luigi.

## Controls and power-ups

- **D-pad:** move; **Down** crouches Super/Fire Mario or Luigi.
- **A:** jump, with SMB1 variable height. In water, press A again for swimming strokes. Walk into a low platform/shore edge to step out of water without jumping, as in Contra.
- **Down + A:** drop through a one-way platform to the next surface below. Release A before dropping again. Solid ground keeps its normal jump; horizontal platforms retain Contra's check for a landing surface below.
- **B + direction:** run and fire the equipped Contra gun. Guns work in Small, Super and Fire form. A fresh B press in Fire form also throws a Mario fireball; each player can have two fireballs active alongside their gun bullets. Machine gun and laser retain held-B firing.
- **D-pad while firing:** Contra's original up/diagonal/down aiming for the gun; Mario fireballs travel in the facing direction.
- **Up:** advance after clearing a base room.
- **Start:** original menu/pause behavior.
- **Invincibility code:** pause with Start, hold Up, press **B, A, A, B** separately, then unpause. The 1-up jingle confirms activation. Either controller can enter the code; both players become immune to enemy/projectile damage. Pit falls retain their native death behavior. The code stays active across levels and lives until returning to the title or resetting the ROM.

Each new life starts small with the standard Contra rifle. Two Mario supplies appear nearby after landing: collect a mushroom to grow, then a flower to gain fire power. Supplies are shared like Contra's original weapon pickups. Native capsules and carriers drop Contra's original weapon pickups: M, F, S, L, rapid fire, barrier and the screen-clearing pickup keep their native effects. Gun pickups preserve Mario's size and Fire Flower power; the nearby mushroom/flower supplies preserve his equipped gun. Extra Mario supplies retain Fire form.

Starting a new game resets both players' Mario state, including the supply allowance used during the demo. Attract sequences discard their final terrain command before returning to the title, so a last-frame scroll cannot hang the title's graphics reader.

Land on an enemy from above to bounce and defeat it. Bosses with larger health pools take stomp damage. Stomps include attackable carriers that originally required bullets, and preserve native scores, defeat routines and drops. Bullets, mortar shots and other projectile classes remain hazards. A landing accepts the edges of Mario's feet, permits neighboring enemies in the same frame, and grants 16 frames of contact protection without blinking.

Enemy contact shrinks Super/Fire characters to small form with temporary invulnerability, retaining the equipped Contra gun. Small characters lose a life and respawn with the standard rifle and fresh Mario supplies. Enemy collision follows the character's actual body size, including while airborne. Jumping above the screen safely tracks the offscreen position and returns to gameplay.

Outside, Mario fireballs bounce on the terrain. Background weak points receive a small edge allowance and take hits before a wall impact consumes the fireball; nearby background targets remain reachable through the solid tiles used to draw them. The Jungle boss's core and both cannons can be hit, and the native tunnel/next-stage sequence runs after the core is destroyed. Base hallways retain native gun perspective and add separate fireballs traveling into the background in Fire form. Base transitions, scrolling, moving platforms, enemies, bosses, music, scoring, lives and stage flow remain native Contra systems. Scripted transitions keep Mario/Luigi's walk and jump poses.

Both base levels retain their visible native background palettes and entrance/room fades. Mario/Luigi palette updates use a separate pending flag so they cannot block Contra's background palette animation or leave a base room black.

Attract-mode demos prepare and draw both Mario and Luigi using the same sprite/CHR path as gameplay. When SMB movement stops, Contra's native X velocity is cleared too, preventing a stale backward step from carrying into native movement and animation.

The user-supplied rifle sheet provides standing, walking, skidding, jumping, crouching, swimming, throwing and death art. Actual Contra gunshots briefly use its recoil variants. Small characters have their own crouch art, retaining their original small collision height. The rifles use each stage's native weapon palette (sprite palette 3), preserving enemy colors; their gray/black appearance can change with the stage. Mario/Luigi's body colors and independent Fire forms remain. Intermediate growth art comes from SMB1. Source PNG and conversion details are in `assets/`.

Rifles follow Contra's native up, diagonal and downward aim. Grounded Down keeps the crouched horizontal shot; Down in the air points straight down. Visible facing and Mario fireballs follow the gun's horizontal facing even when Down+direction suppresses SMB movement. Movement physics are unchanged. Base hallways use the newly supplied back-facing idle/walk/jump/crouch/throw art and a rifle aimed into the hallway; outdoor and base-boss rooms retain the side view. The shared directional source and permission note are in the parent workspace's `assets/`.

This integration does not add SMB levels, pipes, flagpoles, vines or question blocks. Contra's original title, HUD life icons and ending presentation remain.

Water exits lift the feet onto a reachable shore up to one 16-pixel cell high. Both sides of the character must fit above it, so low ceilings and taller banks still block the exit. Swimming remains active while feet overlap a shore cell until the character can stand on top, and the outer foot supports a partial edge landing. Buoyancy uses the entered water surface and Contra's 240-pixel nametable wrap.

Collapsing bridges retain signed screen positions when calculating tile, palette and collision addresses, so running past an explosion cannot wrap its updates into the opposite background nametable.

Later-stage repairs: solid ledges use Mario's body probes without a second incompatible Contra wall test; Super/Fire characters automatically keep their crouched height in low passages. Native carts and rock platforms keep their landing planes and carry an idle rider, who can jump off normally. Base room transitions keep native control until the exit jump finishes. End-of-level departures remain hidden, retain background priority, and keep the native lift beneath Mario in both bases. Boss stomps use the real actor shape and apply gradual damage even at low HP; perspective-room back-wall targets cannot be stomped from the foreground. New-stage loading does not duplicate the supplies from the same life.

Sprite rendering writes directly to a shared DMA page with reserved Mario/fireball slots. Movement probes the destination first and resolves blocked motion in pixels, with one native camera update per frame. Collision lookups are checked against 20,000 native probes. These reduce added CPU work substantially, especially in the opening co-op route; dense late-stage co-op gun/enemy volleys can still slow down on the NES CPU.

## Build

Required unchanged local originals:

- `C:\nes\Contra (USA).nes` — SHA-256 `1f4a9b3f04e2f828688512c0b83611a87c3fc1bd4f85ed91da1b19abc5816d73`
- `C:\nes\Super Mario Bros. (World).nes` — SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`

The project uses the annotated [Contra US disassembly](https://github.com/vermiceli/nes-contra-us) at `687d651c021fd7020f10d05b970ccb62663c94bd` and the Windows ca65/ld65 tools in [smb1base](https://github.com/smbstudio/smb1base) at `46ff88f7d9e854db80bf8d50e5bf74340fcc64ce`. Both repositories are under the parent workspace's `vendor/` directory. Original game assets are extracted locally during the build.

From the parent workspace:

```powershell
python contra/tools/native.py
python contra/tools/build.py
python contra/tools/verify.py
python contra/tools/build.py --install
```

The reference build must reproduce every original Contra PRG byte before integration. The hack expands the ROM to 256 KiB, keeps the original UxROM bus-conflict behavior with a bank-safe switch table, and reserves 8 KiB RAM for both controllers, staged CHR and sprite composition. Changed player poses upload during vblank and yield to native terrain transfers. Delayed requests follow the player's current pose, cancel obsolete intermediate poses, and prioritize leaving a jump pose after landing. Mario and Luigi receive the first hardware sprite slots. Four Mario fireballs use separate RAM and sprite composition, leaving all 16 native gun slots intact. Their CHR pair is separate from the original gun graphics.

Rifle tiles occupy original-player-only CHR slots, verified against every native metasprite including shared tails. They load once while rendering is disabled. Recoil body art uses compact XOR patches, keeping each frame's player CHR transfer at 128 bytes. The gun OAM changes with the displayed body pose, including after terrain traffic delays an upload. The two rifles reserve four hardware sprites; native actors retain 48 slots and their original sprite permutation.

Additional rifle angles load from PRG bank 9 into retired player-only slots. Back-view frames are cached at `$6900`–`$767F` during forced blank. Rendering locks both player buffers while updating them, so the NMI reads the selected completed buffer directly instead of making another 128-byte staging copy. No extra per-frame CHR transfer or hardware sprite slots are needed for the angles or back views.

Outputs are in `contra/dist/`. Installation copies a separately named ROM and IPS patch into `C:\nes`, retaining any differing previous build in a hash-named backup. The original ROMs are unchanged.

## Verification

`dist/verification.json` identifies the exact tested ROM hash. The suite uses the installed `C:\mesen2\Mesen.exe`, Python and `py65` from the parent workspace's requirements file.

- 108 land-movement cases / 8,640 updates compared with the original SMB1 ROM instructions, across both controllers and all three forms.
- 432 assembled-renderer comparisons against the supplied PNG, covering both players, both facings, every pose, repeated recoil toggles and complete hiding. Hardware replays check controller-driven ready/recoil/crouch/swimming poses, palette selection, deferred transfers and final sprite DMA. All eight stages check that native loading preserves the rifle CHR.
- 4,800 assembled aim cases cover native aim codes, grounded/airborne states, both facings/players, recoil and rotated source pixels. Another 450 checks verify exact supplied back-view pixels and switches between side/base views. Controller replays exercise every aim class in all forms, real bullet direction, airborne Down, ground crouching, deferred uploads and both base hallways.
- A controller-only opening collects the supplied mushroom and flower and fires. Two-player input, native pickups, shrink, small-form death, retries and new-life supplies have separate tests.
- Adjacent-enemy stomps in every form, native capsule drops, fireball-only kills, overhead bullets against small/tall bodies, gun retention on shrink, and independent two-fireball limits outdoors and in both bases.
- All five gun types and rapid-fire pickups for both players in Small/Fire forms, Super-form shooting, native weapon pickups in both bases, and two-player volleys reaching 16 native bullets alongside four Mario fireballs.
- The actual Jungle boss approach, native targets and full HP: both controllers defeat the core and damage both turrets with fireballs alone or the standard rifle while small, then advance through the native tunnel into Base 1. Combat fixtures isolate enemy damage and seed the approach; they are not unassisted stage clears.
- All eight stage openings, all player forms, correct pose CHR at display enable, hardware sprite DMA and vblank-only graphics writes.
- Opening jumps and landings for both players in all three forms while player uploads wait for simulated terrain traffic. After the wait ends, hardware CHR must show a grounded pose, with live gameplay and continued walking. This regression fails on the previous ROM.
- Running camera movement over 1,100 pixels and vertical jumping over 380 pixels, with both players active; water strokes and above-screen jumps in all forms.
- Water-to-platform exits with both players and all forms, walking/running from both directions, solid/one-way shores, underwater overlap, scrolled terrain, low ceilings and taller banks. A controller-driven Jungle route crosses the actual water section and walks back onto land without A.
- Down + A in both controllers and every form, lower-platform landings, held-button behavior, solid ground, blocked/pit destinations, and vertical stages with scrolled terrain.
- Full-speed Jungle bridge replays in one- and two-player modes check actual tile/attribute/cache addresses and display timing, including collapsing sections that cross the left screen edge. The address regression fails on the previous build.
- Native room advancement in both base stages, including completed entrance/next-room fades and visible hardware background palettes. The palette regression fails on the previous build. Original ROM hashes, exact reference PRG reconstruction and exact IPS reconstruction are checked.
- Controller-only attract-mode visibility for both players; paused cheat entry, wrong/missing/held-button rejection, activation jingle and real contact protection in Small/Fire forms with either controller; ground braking after release, held B and a direction reversal.
- Three complete attract sequences and title returns without input. Starting solo/co-op after a completed demo or cancelling with Start/Select checks small form, two visible supplies per player, mushroom/flower collection and firing. Both the demo-return and fresh-supply regressions fail on the previous ROM.

Most integration cases deliberately seed RAM to isolate behavior. The full campaign and ending have not been cleared; the stage-opening and fixture coverage is not a complete playthrough.

## Source physics corrections (23 October 2026)

Grounded Down+direction now follows SMB1's input filter, while raw Contra gun aiming and Down+A drop-throughs remain available. Ledge departures retain the falling force selected by the preceding jump. Expanded tests execute 696 cases and 97,440 updates against assembled, unmodified SMB1base movement routines, followed by live-ROM trace replays on both controllers.

The exact live movement trace fixture disables the DMC audio channel immediately before native controller reads. Otherwise a DMC read glitch can make Contra's existing two-read input filter retain the preceding frame's buttons and shift the scripted jump edge. Controls still arrive through emulated controllers and every movement-state/coordinate comparison remains exact. Other replays keep audio enabled; the released ROM keeps Contra's audio and controller routines.

Fireballs reuse an enemy's collision box across a volley and rebuild it after native damage changes the actor. The corrected-physics co-op profiling replay improved from 390 to 422 updates over 600 video frames (the full-suite run measured 421). Crowded scenes can still miss video frames; this is not a constant-60-Hz guarantee.

The later rifle-art update adds gun sprites and recoil changes. Its crowded co-op profiling replay measures 381 updates over 600 video frames; the base, snow and late-stage fixtures measure 533, 485 and 343 respectively. All retain the established performance thresholds, but the additional art has a measurable cost compared with the prior 421-update opening fixture.

The subsequent angled-rifle/back-view update removes the redundant staging copy. The same four fixtures measure 389, 558, 486 and 353 updates over 600 video frames. Crowded co-op scenes still slow down.


The title now uses the user's supplied Mario & Luigi / Contra image, with its original mushroom as the movable selection cursor. Background and sprite tiles reconstruct every source pixel. A sprite-zero split switches background pattern tables near scanline 128; the title uses 44 sprites and respects the eight-sprites-per-scanline limit. Native player selection, intro timing/music, attract demos and real-game startup remain in place. See `assets/TITLE-SOURCE.md` for the source hash and color mapping. Reload the ROM from reset after updating; older save states do not contain the title assets or current streaming state.


The title-only release retains byte-identical gameplay code in bank 8 and the original gameplay VRAM routine prefix. Verification pins the snow benchmark RNG/frame sequence because the title's raster wait changes the native idle RNG spin count. The previous verified ROM measures 429/600 updates on that controlled fixture; the title build measures 463/600. Dense co-op play still has native slow frames, and other live scenarios retain their existing bounds. Projectile and boss replays hold each B tap for three video frames so a native lag frame cannot discard a single-frame tap. Other gameplay/audio replays remain live.


## Lives-screen, complete-body and blinking-title repair (23 October 2026)

The first lives screen restores the original font atlas before the native
score/lives initialization. Pixel comparisons against the unchanged original
ROM cover solo/co-op cold starts and starts after an actual demo. Native
stage-exit tests also verify the next stage's intermediate lives font.

Rifle extraction now restores Mario's occluded body pixels from SMB1 beneath
the source rifle. The custom small crouch uses the small standing torso for
the occluded region. Every visible supplied body pixel is preserved. Rifle
sprites have priority over the complete body, so the horizontal source image
still reconstructs exactly and rotated guns cannot expose a transparent
waist. Reserved gameplay OAM slots are rifles 0..3, bodies 4..11, fireballs
12..15; native actors retain slots 16..63. The per-frame sprite/transfer count
is unchanged, and recoil patches are smaller.

The title uses the supplied closed/half-open eyes with separate timers and
rest sequences for Mario and Luigi. Both perform the GIF's double blink.
All CHR is preloaded and the existing vblank queue changes tile references.
See assets/TITLE-SOURCE.md for provenance, frame timing and sprite budget.

These changes supersede the previous title-only release's gameplay-code hash
isolation assertion: the renderer's OAM addresses intentionally changed.
The separate source-physics and collision equivalence checks remain in force.


## Title/demo handoff and water-entry momentum (23 October 2026)

The title raster split now follows display ownership in TitleDraw, rather
than only the title's game-routine IDs. Native demo initialization spends
one additional frame showing the title before it begins a forced-blank
level load. That frame now keeps the correct upper/lower pattern tables.
Replays compare every pixel in the final countdown and handoff frames for
all three natural attract stages, with either selection cursor mode. The previous ROM
exposes 6,412 incorrect pixels in the setup frame.

A dry-to-wet contact now clears land running flags/timer and clamps only
overspeed horizontal momentum to SMB's normal airborne-water limit,
using MaxLeftXSpdData[1]/MaxRightXSpdData[1] ($E8/$18). The subpixel
position is preserved. This host transition is required because SMB's
high-speed airborne branch can otherwise keep the land speed limit when
Contra changes its environment under an already-running player.

Controller replays build the full land speed ($28 magnitude), enter two
independent pool columns at different times, continue holding B, and then
release movement. The other dry player must retain full running speed.
Both players, directions and all three forms must stay
within water speed on the first wet update and throughout swimming.
The source-verified dry-land integrator remains covered separately.


The corrected water limit changes the Jungle bridge replay's scroll and
explosion timing. Natural solo/co-op routes still verify actual native
tile/attribute/collision targets and vblank timing. The natural solo route
now produces eight valid tile updates but no negative-X updates. A separate
fixture positions already-activated native bridge actors at screen X=32
before their update, preserving their real explosion state machines and
PPU queue. Its previous-section offsets cross the left edge; six signed
updates verify the original left-edge regression without requiring the
old excessive swimming speed. This controlled fixture is explicitly
separate from the natural controller route.

## Base-room growth and crouched collision (30 October 2026)

The power-change timer now advances while Contra owns the base-room walking
script. Collecting a mushroom immediately before holding Up no longer freezes
the small back-facing pose until the next room. Both players are exercised in
both base stages through a real pickup and the native room-advance handler.

Small Mario's stationary grounded crouch now lowers the collision-box head by
four pixels to match the artwork. Jumping and Down plus movement restore the
normal small box. A 216-case CPU check covers both players, all forms, native
jump flags and direction/button combinations. The complete suite passes 271
checks for this build. Existing weapon, stomp, air-control and supply choices
are retained; the tester's proposed balance changes were not applied.

Sprite-sheet credit: metalwario64 and superphanto. Testing: cecilou, jroweboy
and fanatik. See the repository's CREDITS.md for full attribution.

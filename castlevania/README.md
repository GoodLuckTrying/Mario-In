# Mario in Castlevania

Recovered from the separate `castlevania smb` project. This is the current
installed build, SHA-256 `6f2948358135e50d33ecbf5c5ff742709886faea752ec65d71f37f9611152c51`.

Mario in Castlevania - native NES ROM hack

Open `C:\nes\Mario In\Mario in Castlevania.nes` in an NES 2.0 emulator supporting MMC5
(mapper 5) with 16KB CHR RAM, such as Mesen. Reload the ROM and start a new game.

Left/Right: move with SMB acceleration, friction and reversal.
Movement preserves SMB position subpixels through camera scrolling.
A: jump. Hold for a higher jump; release for a shorter jump.
B: run and swing the whip on each new press.
Down: crouch grown Mario and coast with SMB ground friction. A can jump while crouched.
Down+B: strike lower. Holding/releasing Down adjusts the whip height.
Standing Fire Mario also shoots on the same B press (two fireballs maximum).
Crouching prevents fireball throws, as in SMB; Down+B still uses the whip.
Up+B: use your collected Castlevania subweapon. It costs hearts.
Up/Down: use Castlevania stairs.
Start: start or pause.

Break lamps with the whip or fireballs. Jumping into lamps does not break them.
Both weapons break Castlevania's breakable bricks and reveal their hidden items.
The whip grows from a short leather whip to a longer chain when Mario grows.
Whipping allows movement and jumping; holding B does not repeat the swing.
Small Mario receives a mushroom; Super Mario receives a Fire Flower.
Fire Mario receives hearts, with native subweapon drops preserved.
Each custom small heart adds one heart and refreshes the HUD, capped at 99.
Native large hearts retain their five-heart reward.
Land on eligible enemies to damage them and bounce.
Enemy hits reduce the original health bar. Mario keeps size and fire power
until a hit leaves 16 HP or less (the final quarter); then he becomes small.
The whip remains available at either size.
Small Mario survives enemy hits until health reaches zero.
Hits grant temporary invincibility. Food restores health as in Castlevania:
24 health points, up to the original maximum of 64.

The engine uses 8x16 sprites. Mario's original 8x8 tiles are paired for it.
Your original Castlevania and Super Mario Bros. ROMs remain unchanged.
The IPS applies to Castlevania (USA) (Rev 1).

Verification includes exact motion comparisons against your SMB ROM,
360 movement cases / 19,805 ordinary position and subpixel updates covering
jumping, landing, walking, running, braking, air turns, crouch slides and jumps,
ledges, ceilings, wall contacts, corners, steps, button release/repress and
combined directional inputs. Native Castlevania pit deaths are checked separately.
Additional checks cover stomp fractions, fireball launch positions, first-frame
platform detachment, SMB combat bounds and ledge-fall animation,
all original sprite/background pixels, pickup and health HUD checks, food, whip,
native weapons, collision, combat, scrolling, doors,
native fish-man spawn/shoot/splash paths and stair room round trips at all sizes,
all stage/room camera limits, boss-lock activation and lowered whip attacks,
death/respawn, and a fresh-start controller route through the first door.
Boss damage has directed fixtures; a full-game playthrough is not verified.
The MMC5 HUD interrupt frees CPU time for gameplay. Original HUD/background
display pixels and crowded sprite allocation have separate regression checks.

Source and repeatable tests:
castlevania/
Rebuild from repo root: python tools/build_port.py castlevania
Verify from castlevania/: python tools/verify.py


The packaging update uses the repo's pinned Windows cc65 instead of the original
WSL installation. It preserves the assembly and requires an identical rebuilt
ROM and IPS. The original SMB and Castlevania source references are pinned in
`reference/`. Current validation evidence is in `../release/verification/`.

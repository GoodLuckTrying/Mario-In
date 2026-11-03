# Mario in Mike Tyson's Punch-Out!!

Open `C:\nes\Mario In\Mario in Mike Tyson's Punch-Out!!.nes` and start a fresh game.
This uses the Tyson Revision 1 game, with the original opponents and circuits.

- Original A/B punches, Up for head punches, left/right dodging, Down block/duck, and Start star uppercuts remain.
- A fresh B press also launches a fireball; Up+B aims at the head. Two fireballs can be active while Mario has punching stamina.
- Shots use a bright 16-pixel rolling fireball, launch at the current throwing hand, and rise/fall on a vertical arc while advancing toward the opponent.
- Native defenses and vulnerability windows still apply. Fireballs use native damage, stars, scoring, knockdowns, referee counts and TKO/progression routines.
- Mario uses the permissioned front/back/turned sprites supplied by the user. Punches use the supplied upper-body poses with planted feet. Ordinary hits use standing recoil; lying-down art is reserved for native knockdowns. Native damage, dodge timing, knockdowns and recovery remain.

This is an adaptation to boxing, retaining the original health and movement rules.
There is no platform gravity or jump button. Opponents retain their original graphics and palettes. The referee uses the shared Fire palette in the ring.

## Rendering and source

Little Mac is a background actor. Mario therefore uses the native background drawing path, with a private atlas sharing the same MMC2 bank as all native referee tiles. A tile shadow restores the background beneath shots. Fireballs use the background plane rather than taking the opponent's sprite slots, so they move on an 8-pixel tile grid. Native palette and queued HUD uploads obey the vblank job budget.

The front portrait and displayed name are replaced separately. Doc Louis and the opponent portraits remain native. The original title, circuits, boxing controls and opponent scripts are retained.

The guard uses the rear diagonal head and raised arm with planted standing legs. Fire Mario's cap/shirt and hair/shoes use the correct white/red roles. Artwork is aligned to 8-pixel tile boundaries so all 116 referee/announcement tiles fit alongside Mario. The art decoder is checked against the original 6502 renderer, including repeated tile runs immediately after column changes. CHR0 remains byte-identical for the referee's FD-latched tiles; the replacement portrait uses its own copy in the retired Mac CHR3 bank.

Mario's body uses a stable ring position and floor anchor. Native Mac commands include cropped torso redraws and clipped entry frames; their individual visible bounds do not represent an actor position. They no longer reposition Mario between poses. Native lower-background scrolling still supplies pixel movement for dodges and scripted horizontal motion.

The pinned [nmikstas disassembly](https://github.com/nmikstas/mike-tysons-punch-out-disassembly), revision `60b2fa0e61d57b10b5fadc04be96241d25755d25`, rebuilds the local Revision 1 PRG and CHR exactly. Base SHA-256: `e1e7ea03309e370240e90ad80815b484e1c537107d8620e2479f8169cf237c8f`. The original ROM is preserved. Source art permission and credit are recorded in `assets/DIRECTIONAL-SOURCE.md` at the workspace root; no artist name was supplied.

The ROM keeps mapper 9 and the native 128 KiB PRG / 128 KiB CHR layout. The NES 2.0 header declares 8 KiB volatile work RAM for private state and the background shadow. Old original-game save states lack this state. Physical cartridge compatibility has not been verified.

## Build and verification

From the workspace root:

```powershell
python punchout/tools/build.py
python punchout/tools/verify.py --install
```

The release receipt binds instruction tests, controller replays, all fourteen native fight loads including Tyson, hardware fireball tiles, launch alignment, visible bouncing, vblank timing, all 47 referee commands, actual referee count/get-up/Fight/TKO sequences and a finishing-fireball TKO/progression fixture to the exact ROM hash. The attract/demo exit is also checked. The TKO fixture stages a third knockdown; this is not a full campaign or ending clear.

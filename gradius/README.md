# Mario and Luigi in Gradius

Fire Mario flies through the original NES Gradius with gravity and hold-Up lift,
and Mario fireballs as the default attack. The fireballs spin, fall under gravity, bounce off floors and
extinguish against walls/ceilings. They use the original enemy and boss damage
system. DOUBLE has separate two-shot pools for forward and upward fireballs:
two of each can be active per firing origin, including each Option. Each Option is
another complete swimming copy of the current brother, following and shooting through the native
Option system. LASER retains the native laser upgrade;
missiles, speed upgrades, barrier, capsules, scoring, alternating players,
stages and music retain their native Gradius behavior.

Design references supplied by the user:
- https://x.com/fugudaro/status/2098026870185074756
- https://x.com/fugudaro/status/2098606020691927383

## Play

Open `C:\nes\Mario In\Mario in Gradius.nes` from a fresh boot in an NES 2.0 compatible
emulator such as the installed Mesen. Do not load an old unmodified-ROM save state.

On the title screen, Select moves the restored ship pointer between **1 PLAYER**
and **2 PLAYERS**; Start begins the selected mode. The original alternating
two-player mode uses Mario for player 1 and Luigi for player 2, with the active
player's controller handling movement and firing. Options match their owner.

- Left/Right: horizontal flight, with Gradius speed upgrades.
- Hold Up: counter gravity and lift Mario. Release Up to fall; Down accelerates descent.
  Lift reverses falling momentum smoothly. Speed upgrades also increase maximum lift speed.
- A: throw fireballs (hold for native autofire); also fires equipped missiles and Options.
- B: activate the selected Gradius power-up.
- Start: pause/unpause.
- Invincibility: pause, hold **Up**, separately press **B, A, A, B**, release Up,
  then unpause. A confirmation jingle plays on unpause. The code protects against
  enemy, bullet and terrain contact. Either controller can enter it. It remains
  active through deaths/stage transitions until reset or leaving gameplay.

Mario cycles through SMB1's three original large swimming poses in Fire Mario
colors adapted to Gradius's existing warm sprite palette. Animation freezes while
paused. Luigi uses bright green, skin and white; fireballs keep their warm colors.
During Luigi's turn, one shared sprite shade changes from teal to green, also
affecting enemies that use that shade. Mario's turn restores the native shade.
Neutral gravity is gentler and terminal fall speed is 2 pixels per update;
holding Down allows faster descent. The Gradius player collision box and horizontal
movement are retained. Gravity and lift use subpixel momentum, freeze while paused,
and reset on respawn/stage initialization. Mario's lower screen limit is slightly higher to keep his
feet clear of the status bar. Attract mode also shows Mario and his fireballs.

## Build and verification

From the workspace root:

```
python gradius/tools/build.py
python gradius/tools/verify.py
python gradius/tools/build.py --install
```

Build inputs, never modified:
- `C:\nes\Gradius (USA).nes`, SHA256
  `38c44e0e6f531a2779271f10cd4daa08ee2616c59c49d476b6f4e9dc482bf5f3`
- `C:\nes\Super Mario Bros. (World).nes`, SHA256
  `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`

The build uses the workspace's existing SMB artwork extractor and ca65/ld65 tools.
`dist` contains the ROM, IPS patch, build manifest and verification receipt bound
to the output ROM's SHA256. The IPS patch applies to the original Gradius above.
Installation requires a passing verification receipt for the exact output ROM;
the previous installed version is backed up before replacement.

Mesen replays cover cold boot, horizontal flight, gravity, hold-Up lift for both
controllers at three speed levels, simultaneous A fire, pause/resume momentum, Options
following gravity with no direction held, complete body rendering,
real-wave fireball kills, native laser/missiles/Options, visible attract mode,
three hardware-rendered swimming poses and animation pause, independent DOUBLE
2+2 limits and refills for both controllers with/without Options, a full 12-shot
DOUBLE pool, and one native player-contact sweep per frame,
both controllers acquiring two Mario Options through the native B power-up menu,
complete Option art/positions/firing, simultaneous Options/missiles/12 fireballs
against real waves in all seven stages, and forced busy-frame rendering recovery,
all seven stage openings, 60 completed updates in 60 video frames in the opening
windows, status-bar split timing, VRAM upload timing, valid/invalid cheat entry,
the confirmation sound, and enemy/bullet/terrain damage with and without the cheat.
The title replay checks the original pointer graphics and both selector positions.
A two-player replay selects the mode from cold boot and follows actual native
contact deaths through Mario, Luigi and back to Mario, checking lives, rendered
palettes, fireballs and Luigi acquiring two Options. It uses contact, protection
and power-up-meter fixtures to exercise those transitions deterministically.
6502 execution cases additionally cover exact gravity/lift integration and bounds
for both controllers at five speed levels, reset behavior, all six fireball slots,
fireball gravity, floor bounces, walls, DOUBLE, LASER and Big Core's actual six-hit
defeat chain using both original and extra shots.
They also compare 200 randomized projectile collision scenes with the native
collision engine and check all sixteen native moving-arm rendering angles and
both projectile pools against the arm weak point.
These fixtures are not a full unassisted campaign clear.

## Implementation

The ROM remains CNROM (mapper 3, submapper 2 with bus conflicts), expanded to
128 KB CHR ROM and 8 KB work RAM. A 53-byte bootstrap copies the assembled code
from an extra CHR bank to work RAM before returning to the native boot sequence.
Only the player and default/double projectile tile pairs change in the original
CHR banks. Three copies of the four stage banks supply the swimming poses without
rewriting pattern memory during rendering. Bank switches retain native instruction
timing and use bus-safe ROM addresses. Backgrounds, enemies, the barrier and sprite-zero graphics remain exact.
A separate untouched copy of the original title CHR bank preserves the ship
pointer, whose tiles overlap the custom swimming artwork in gameplay banks.
Native palette tables remain untouched; a vblank palette update applies Luigi's
approved shared green shade during his turn and restores teal for Mario.

The custom OAM buffer keeps the native sprite-zero marker first, puts complete
Mario/Option bodies next, and draws the remaining scene directly into the final
DMA buffer. Enemy/bullet order rotates to share hardware sprite priority.
Native metasprite coordinates, tiles, attributes and moving-arm graphics are
preserved. This avoids the old draw/hide/copy passes that overran the status-bar
split with Options and many fireballs. NES sprite limits still apply.

Collision candidates and moving-arm segments are prepared once per update.
Native shot/contact order is retained. Crowded extra-shot waves can defer the
remaining terrain sweeps until after the time-critical status-bar split;
extra-shot collisions also run there. Fireballs
avoid a redundant native terrain probe already covered by their physics.
Native lag frames restore the last displayed playfield bank/scroll and
perform their own correctly timed HUD split, rather than leaving the entire
background on the HUD graphics bank. No partial OAM or VRAM upload is used for
that repeated frame.

DOUBLE's six extra logical shot slots live in work RAM. They share the original
projectile physics and native shot-versus-enemy/bullet/boss damage dispatcher.
Only an actual collision temporarily exchanges the colliding slot. Extra shots
have their own draw records and limits; they do
not allocate enemy slots or repeat player/missile contact processing. Both directions
can refill independently when only one side has room for another fireball.

Read-only address research used Fabulu's Mixup Gradius reverse-engineering notes:
https://github.com/Fabulu/Mixup at commit
`314625258387309119e69e37aaf3365197235119`. This mod runs the native 6502 game.

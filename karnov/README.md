# Mario in Karnov

Mario starts in permanent Fire form. Karnov's native health, inventory,
equipment and progression remain in place. A jumps; holding B while moving
uses SMB1 running physics. B keeps Karnov's collected attack and adds up to
two independent bouncing Mario fireballs. Small enemies can be stomped;
bosses, projectiles and tougher actors retain their native rules.

Native ladder, flight, water, injury, death and scripted states own their
movement. Their original equipment controls are retained. Ordinary land
movement uses the source-verified SMB1 motor, with Mario's full-body wall
and ceiling probes, crouching, variable jump height, braking and skidding.
The native camera and stage boundaries still constrain movement. Health
damage does not introduce a mushroom/shrink system.

## Build, verify and install

From the repository root, with Python and the pinned toolchain bootstrapped:

```powershell
python karnov/tools/build.py
python karnov/tools/verify.py
python tools/install_new_port.py karnov
```

Required inputs in `C:/nes`:

- `Karnov (USA).nes`: SHA-256 `0d49c1120fc13ead1efe4429f7cbb4f01b90e2486c66661c46e922dda6dc830a`.
- `Super Mario Bros. (World).nes`: SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`.

Outputs are `dist/Mario in Karnov.nes` and `.ips`. Installation requires a
passing receipt for the exact output hash and preserves a hash-named backup
of a differing previous modified ROM. Original inputs are never overwritten.
Start from a fresh boot; original or earlier-build save states do not contain
the new mapper and private state.

## Native integration

There is no external NES source disassembly in this project. Hooks are checked
against the exact USA ROM; `tools/research.py` and the discovery fixture were
used to trace physical banks, controllers, OAM and collision ownership.

The original Namcot 108/mapper 206 layout becomes MMC3 with 256 KiB PRG,
128 KiB CHR and 8 KiB private work RAM. Native CHR register masks and horizontal
mirroring are preserved. The two original fixed 8 KiB PRG banks are duplicated
at the expanded fixed-bank locations. IRQs remain disabled as in the original.
The original 64 KiB CHR payload is retained byte for byte.

| Native location | Integration |
| --- | --- |
| Fixed `$F297` | Player dispatch; special native states retain their handlers |
| Fixed `$FA74` | Native attack plus Mario fireballs, including native equipment states |
| Fixed `$D19B`; physical bank 12 `$A0ED` | Stage and checkpoint/life initialization |
| Physical bank 11 `$A003` | Complete four-cell Mario body; native sprite-zero marker retained |
| Fixed `$C046` | Palette allocation after the native OAM page is complete |
| Physical bank 12 `$A01E`; fixed `$E0B1` | Two vertical camera pixels and both terrain upload packets |
| Fixed `$E093/$E09E` | Vblank palette upload and original CHR-register masking |
| Fixed `$C969/$CCA7` | Stomp handling and existing enemy damage processing |

Terrain probes use the native `$C3D8` map lookup and its `$9BCA/$9AC8` metatile
collision decoding. One-way landing alignment and hazardous terrain remain
distinct. Camera displacement is measured in pixels, rather than inferred
from a velocity field. Fireballs occupy the two body slots freed by replacing
the original six-cell character with four cells.

Mario uses cloned 1 KiB CHR pages for native player banks 0, 1, 2, 3 and 24.
Only retired player patterns change inside those clones. Palette allocation
examines completed OAM; equal native palettes can share an index before a
free palette is assigned to Mario. During native injury, HUD and weapon sprites
keep their normal shared shades while Mario keeps his Fire colors. Allocation
never relies on the previous frame's enemy palette usage.

The lives screen and native entrance use Mario before their first visible DMA.
Vertical camera strips advance two pixels per update, preserving both original
tile/attribute packets and any HUD rows. An airborne viewport guard waits for
an available native scroll instead of treating its lower edge as a pit. Grounded
support remains native, and falling into a real pit still triggers death.
This also covers a horizontal strip that must finish before the camera can
follow a long fall downward. Permission uses the host's level-map bounds and
scroll locks; a missing lower area remains a pit.

## Verification and limits

The current receipt contains 23 checks. The source comparison executes 110
cases and 15,400 movement updates against verbatim assembled routines from
`smb1base` commit `46ff88f7d9e854db80bf8d50e5bf74340fcc64ce`, with SMB2J features
disabled. Separate 6502 cases exercise native enemy damage, stomp rejection,
paired contacts and the two-shot limit. Another 654 cases cover native state
handoffs, metatile decoding, camera wrap and crowded injury palettes.
An additional 4,536 cases compare downward-scroll permission with the actual
native level-map query and scroll-lock rules across all nine stage maps.

Mesen fixtures check all nine stage openings, actual displayed 8x16 CHR and
all three Mario colors, vblank timing, physical jump/run/brake/crouch controls,
native two-hit injury/death and fresh-life initialization. They also check
repeated floor bounces, the original attack and fireball world speed while the
camera scrolls. Controlled contacts and native stage selection are used in
these fixtures. This is not a complete campaign clear or a physical-console
test, and it does not establish constant 60 Hz in every scene.

The presentation/camera regression checks the first visible life/entrance
sprites, up/down strip speed and upload timing. Controlled terrain checks
separately require lower-ground landing, continued support, and real-pit death.
The physical jump test measures world displacement as the camera moves.
Two longer fall fixtures cover a 232-pixel drop, at least eight vertical
terrain strips, moving/stationary inputs, the horizontal-to-vertical camera
handoff and four consecutive updates supported by the lower floor.
The actual first-stage opening ledge is replayed with walking and running/jump
inputs, requiring six consecutive lower-floor support updates. Its native map,
camera and player positions are retained; hostile actors are disabled to isolate
terrain falls from damage. A separate 22-run jump-timing sweep also passed on
this exact ROM; see [the recorded results](../release/karnov-opening-cliff.json).

Sprite-sheet credit for the collection: **metalwario64** and **superphanto**.
Project testing credits: **cecilou**, **jroweboy** and **fanatik**. Original SMB1
and Karnov art retain their existing attribution. See [CREDITS.md](../CREDITS.md).

# Mario in Rygar

Mario starts in permanent Fire form while retaining Rygar's native energy,
equipment, Diskarmor and progression. A jumps in side-view areas. B keeps the
Diskarmor/native action and adds up to two Mario fireballs; holding B while
moving enables SMB1 running. Fireballs bounce on side-view terrain and travel
in the native facing direction in overhead areas. They use the original
enemy weapon-hit processing, so native boss and equipment rules remain relevant.

The native stomp window is more forgiving and now updates Mario's own bounce
state. Native enemies marked unstompable remain excluded. A short protection
window prevents adjacent contacts from immediately undoing a successful stomp.
Damage uses the original energy meter and does not shrink Mario.

Ordinary side-view movement uses the source-verified SMB1 motor. Native
overhead movement, grappling, climbing, other equipment, hurt and death states
retain their original controls and integration. Their camera, collision and
progression state machines are preserved.

## Build, verify and install

From the repository root, after bootstrap:

```powershell
python rygar/tools/build.py
python rygar/tools/verify.py
python tools/install_new_port.py rygar
```

Required inputs in `C:/nes`:

- `Rygar (USA).nes`: SHA-256 `965330fed9f5b8492452f3b53084752e83b7f899a1f88f3c475ece2fde6f9231`.
- `Super Mario Bros. (World).nes`: SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`.

Outputs are `dist/Mario in Rygar.nes` and `.ips`. Installation validates the
exact-hash verification receipt and backs up a differing previous modified
ROM. It leaves original inputs alone. Use a fresh boot with the new ROM;
earlier save states do not contain its private code, graphics or state.

## Native integration

This port uses exact-byte hooks in the USA ROM, with physical-bank and native
controller traces rather than an external source disassembly. Mapper 2's
conflict behavior is retained. PRG grows to 256 KiB and the header adds 8 KiB
work RAM. A loader in verified unused fixed-bank space copies the private
code and art into RAM. Native PRG switching and CHR-RAM loading remain intact.

| Native location in 16 KiB bank 5 | Integration |
| --- | --- |
| `$9BC1` | SMB prediction before the native terrain probes |
| `$9C0A/$A407` | Native collision response and application of the resulting movement |
| `$9C78` | Native overhead movement alongside added fireballs |
| `$ADDF/$ADFA` | Native stomp bounce and brief contact protection |
| `$ACF5` | Existing Diskarmor enemy-hit processing, also used by added fireballs |

Fixed-bank `$C14A/$C117` handle final Mario OAM and vblank colors/art. OAM is
prepared after native logic, leaving the original next-frame DMA at `$C10C`.
This keeps sprite preparation out of the terrain-upload deadline. Bank 6
`$8500` resets private state at actual player initialization. Native health,
actor updates, item stats, dialogue and room transfer handlers stay native.

SMB fractions are kept separately from native fields whose low bits also
hold collision flags. Grounded terrain detection receives the original
downward probe without adding that displacement to Mario's free movement.
Decoded collision response controls walls, ceilings and landing. Fireball
terrain probes read the native two-plane collision bitmap at the visible
ball's edges, with pixel-by-pixel vertical movement. One-way floors only catch
descending balls; a rebound cannot be deleted by its former floor overlap.
Native actors are not borrowed or removed for terrain probes. Camera motion is read as integer
displacement, separate from native velocity units.

Six side-view poses and the fireballs use retired player patterns. Both the
side-view CHR source and the separate overhead source are updated. Native
weapon, enemy and background patterns outside those player ranges are
preserved. Overhead Mario has front, back, side and diagonal views with
walking feet. Climb and skid poses use two inactive/active CHR buffers;
only a complete frame is displayed. Transfers are 32 bytes per vblank and
wait behind larger native VRAM queues. Mario's animation timer is independent
of the counter reused by native enemy spawning. Native sprite priority is
retained when drawing behind foreground terrain.

## Verification and limits

The current receipt contains 17 checks. The motor comparison executes 110
cases and 15,400 updates against assembled `smb1base` movement routines at
commit `46ff88f7d9e854db80bf8d50e5bf74340fcc64ce`, with SMB2J features disabled.
Additional CPU cases exercise native stomp flags, rejection of ascending
contacts, paired contacts and fireball damage without moving the Diskarmor.
Another 811 cases cover native movement handoffs, integer camera wrap and
shot lookup coordinates compared with the native bitmap-reading instructions.

Mesen checks physical controls, floor bounces with the Diskarmor still active,
fireball world speed through camera movement, energy damage and death/game-over
progression. Graphics checks cover the opening plus four other side-view
entries and three overhead areas, including actual displayed CHR, front/back
views, colors and vblank deadlines. Native entry loading and controlled enemy
contacts isolate those scenarios. The constrained overhead entry uses short
movement pulses so its art check does not intentionally walk into water.
Sustained moving/fire stress also checks that rendering resumes before the
visible scanlines, while the Diskarmor and repeatedly bouncing shots stay active.

These fixtures are not a full campaign clear or a physical-console test.
Native traversal, camera cadence and scene geometry are intentional host
adaptations; the isolated motor comparison does not claim otherwise.

Directional sprite sheet: **metalwario64** and **superphanto**, supplied by the
user with permission. Project testing credits: **cecilou**, **jroweboy** and
**fanatik**. See [asset provenance](../assets/DIRECTIONAL-SOURCE.md) and
[CREDITS.md](../CREDITS.md). Original Rygar/SMB1 assets retain their attribution.

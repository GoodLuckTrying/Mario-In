# Mario in Ghosts 'n Goblins

Open `C:\nes\Mario In\Mario in Ghosts n Goblins.nes` and start fresh. Old original-ROM save states do not contain this port's RAM code. The original USA ROM and other ports are preserved.

- Left/right move Mario; hold B to run. A jumps, with variable height while held.
- B retains the equipped native weapon. In Fire form, a fresh B press also throws a bouncing fireball; two private fireballs can coexist with the native weapon pool.
- Native moving platforms support and carry Mario; landings clear falling state and he can jump away.
- Floor bounces use SMB1's `$FD` upward impulse and `$50` gravity, capped at 3 pixels downward per projectile update. The opening native terrain replay measures a 16-pixel hop rather than the previous oversized arc.
- Down crouches in big form; Up/Down retain native ladders. Start and Select retain native menu/pause behavior.
- Each life starts as Fire Mario. The native armor system controls Fire Mario → Small Mario → death; armor pickups restore Fire Mario. Native alternating two-player mode uses Mario for both turns.
- Descending landings stomp ordinary enemies and give brief protection from adjacent contact. Bosses and dangerous native projectiles keep their original contact rules.

Mario uses SMB1 acceleration, friction, run/skid behavior, subpixels, speed-selected jumps, variable jump height, air steering and crouch momentum. These run inside the original coroutine engine. Since the host commonly updates once every three video frames, normal Mario motion catches up for elapsed video frames, capped at three simulation steps per host update. Native enemies, weapons, ladders, injury scripts, music and scene rendering retain the host's cadence. This is not a claim of constant 60 Hz rendering.

Native weapons, boss weaknesses, shield requirements, keys, doors, map transitions, the frog curse, lives and game-over remain native mechanics. Private fireballs and stomps damage ordinary enemies through native defeat/score handlers. Use the native weapon against bosses; fireballs do not bypass boss equipment requirements. Native armor/weapon pickups retain their original graphics.

## Build and verify

From the workspace root:

```powershell
python ghosts/tools/build.py
python ghosts/tools/verify.py --install
```

Required inputs are `C:\nes\Ghosts'n Goblins (USA).nes` (SHA-256 `a263db625853b563aca356a8651f69c9092428dd2b665b6fd5c75ea5b1439d31`) and the existing SMB1 World ROM. The build checks both hashes. Mario graphics come from that local SMB1 ROM. The physics reference is assembled from the pinned `vendor/smb1base` revision `46ff88f7d9e854db80bf8d50e5bf74340fcc64ce`, with SMB2J features disabled.

No usable NES source disassembly was available for this target. Native code is integrated using checked original hook bytes and mapped native call paths. `research/bank*.txt` are exploratory linear listings and contain data decoded as instructions; they are not a rebuilt source disassembly.

The ROM expands UNROM PRG from 128 to 256 KiB and declares 8 KiB work RAM in its NES 2.0 header. It keeps mapper 2, submapper 2, bus conflicts and native mirroring. An added bank supplies RAM code and art; the original startup is relocated intact and its relative branches retain their layout. This requires an emulator that honors the added NES 2.0 work RAM. Physical cartridge hardware has not been tested.

Player CHR streams into retired Arthur body tiles `$22..$29` and `$38..$3F`, with fireballs at `$40/$41`. Native score/time glyphs (`$00..$0F` and `$1D`), armor (`$20/$21`), princess and frog art remain separate. Arthur's naked frames `$20..$35` are player frames, as selected by the native `$E397` armor-bit logic; they are excluded from the non-player ownership table. The native renderer's non-player meta frames retain their tiles, OAM ordering and frame tables. Two 64-byte art transfers commit a complete pose only after both halves are ready, and a buffer cannot be reused until both OAM pages have released it. Native armor-loss CHR jobs retain armor/frog uploads while skipping Mario-owned tiles. The transfer loop is partially unrolled so the native background attribute job can still run on every eligible NMI.

Mario borrows an unused sprite palette, considering both native OAM pages. Native palette writes are retained in a separate shadow and restored before a slot is returned. Palette selection and form are published only after both OAM pages are complete. The displayed palette stays active throughout construction. While the renderer builds those pages, DMA uses the previous complete OAM list cached in the startup-only `$7F00` RAM; startup has already jumped away before that RAM is reused. When all four slots are busy, Mario uses native colors for that frame; enemy and background colors take priority over exact Mario shades.

The title selector and separate loading/lives actor use Small Mario with their own explicit draw context. Scene changes invalidate the streamed art and discard old private shots before those menu icons are shown.

## Verification scope

`dist/verification.json` binds all completed checks and source/test dependencies to the exact ROM hash. Verification includes assembled SMB source comparisons for both forms and directions; original-versus-candidate non-player OAM comparisons; fireball pool/edge/page fixtures; native Mesen boot, opening scene, attract demo, all seven stage loads, movement, crouching, five weapons plus private fireballs, actual two-player selection/turn change, ladder control, zombie stomping, neighboring contact, native shrink/armor/death/respawn (including complete displayed CHR and all three Mario palette shades on every visible sprite), and a boss finishing-hit/key/door/next-stage fixture. The progression fixture starts a native boss one hit from defeat and stages the native key; it is not a full boss fight.

A moving/shooting replay checks visible VRAM writes, rendering re-enable timing and NMI stack headroom. Most targeted fixtures seed legal native RAM at update boundaries to isolate behavior. No full campaign clear, ending or physical-console verification is claimed.

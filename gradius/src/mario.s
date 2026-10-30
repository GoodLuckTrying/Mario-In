.setcpu "6502"
.macpack longbranch
.include "graphics.inc"
.export Boot,Init,DrawGate,BlankGate,DmaGate,InputGate,PauseGate,DeathGate
.export Compose,CheatInput
.export SpawnAEnd,SpawnBEnd,FireLoop
.export FloatGate,FloatStep,ResetFloat
.export FireGate,DoubleFire,SwapShots,ExtraSweep,CombatGate,Swim
.export EarlyCombat,FinishCombat
.export NmiGate,ScrollGate,BusySplit,BusyHud
.export DrawArms
.export ContactDone,TerrainTail,TerrainGate
.export PaletteGate
G_READY=$7000
G_DRAW=$7001
G_X=$7002
G_Y=$7003
G_ANIM=$7004
G_INV=$7005
G_ARMED=$7006
G_SEQUENCE=$7007
G_SHOT_SAVE=$7010
G_OAM=$9C ; Native drawing scratch, used only while composing sprites.
G_TMP=$7017
G_BUFFER=$7100
G_FIRE_VY=$7020
G_FIRE_FRAC=$7030
G_OLD_Y=$7018
G_DELTA=$7019
G_FIRE_SLOT=$701A
G_FLOAT_VY=$7040 ; Signed eighth-pixels per update.
G_FLOAT_READY=$7041
G_FLOAT_OLD_Y=$7042
G_FLOAT_DELTA=$7043
G_FLOAT_CAP=$7044
G_SWIM_TIMER=$7045
G_SWIM_PHASE=$7046
G_EXTRA_KIND=$7050
G_EXTRA_SUB=$7060
G_EXTRA_X=$7070
G_EXTRA_Y=$7080
G_EXTRA_VY=$7090
G_EXTRA_FRAC=$70A0
G_OWNER=$70B0
G_ROTATION=$70B1
G_ACTOR=$9D
G_COUNT=$98
G_ARM_CURSOR=$70B4
G_TARGET_COUNT=$70B5
G_TARGET_INDEX=$70B6
G_FIRE_TILE=$70B7
G_ARM_COUNT=$70B8
G_ARM_OWNER=$70B9
G_ARM_SEG=$70BA
G_EXTRA_PENDING=$70BB
G_SWEEP_END=$70BC
G_MIN_X=$70BD
G_MAX_X=$70BE
G_COMBAT_PENDING=$70BF
G_LAST_CTRL=$70C0
G_LAST_X=$70C1
G_LAST_Y=$70C2
G_LAST_MASK=$70C3
G_LAST_BANK=$70C4
G_LATE_FIRST=$70C5
G_TERRAIN_DEFER=$70C6
G_TERRAIN_PENDING=$70C7
G_PLAYER_ATTR=$70C8
G_ARM_X=$7200
G_ARM_Y=$7220
G_ARM_ID=$7240
G_ARM_PART=$7260
G_TARGETS=$70E0
G_TARGET_HEIGHT=$70F0
G_BANKS=$70D0

.segment "BOOT"
Boot:
 lda #0
 sta $2000
 sta $2001
 bit $2002
 lda #12
 sta $FFFE
 lda #0
 sta $2006
 sta $2006
 lda $2007
 ldy #0
 sty $00
 lda #$60
 sta $01
 ldx #16
@copy:
 lda $2007
 sta ($00),y
 iny
 bne @copy
 inc $01
 dex
 bne @copy
 jmp Init

.segment "CODE"
Init:
 lda #0
 ldx #0
@clear:
 sta $7000,x
 sta $7100,x
 inx
 bne @clear
 sta $00
 sta $01
 sta $FFFE
 lda #2
 sta G_BANKS+1
 lda #1
 sta G_BANKS+2
 lda #13
 sta G_BANKS+3
 lda #3
 sta G_PLAYER_ATTR
 lda $10
 sta $2000
 jmp $8510

ScrollGate:
 ; Keep the last displayed playfield state for a rare native lag frame.
 lda $10
 sta G_LAST_CTRL
 lda $12
 sta G_LAST_X
 lda $13
 sta G_LAST_Y
 lda $11
 sta G_LAST_MASK
 ldy $2D
 lda G_BANKS,y
 sta G_LAST_BANK
 jmp $8281
NmiGate:
 ldy $04
 bne @busy
 ; The title's ship pointer uses the same tile pairs as Mario. Keep an
 ; untouched native title bank instead of exposing the gameplay artwork.
 lda $00
 cmp #2
 beq @native
 cmp #5
 beq @native
 lda #13
 sta G_BANKS+3
@native:
 jmp $8077
@busy:
 ; The original busy-NMI path skips all PPU setup, leaving the entire
 ; playfield on the HUD's CHR bank. Hold a complete rendered frame instead.
 lda $00
 cmp #2
 beq @play
 cmp #5
 bne @return
@play:
 lda $1B
 bpl @return
 lda $0D
 bne @return
 lda $1E
 beq @return
 lda $1F
 beq @return
 lda G_LAST_BANK
 sta $FFF5
 lda #$20
 sta $2006
 lda #0
 sta $2006
 lda G_LAST_X
 sta $2005
 lda G_LAST_Y
 sta $2005
 lda G_LAST_CTRL
 sta $2000
 lda G_LAST_MASK
 sta $2001
 jsr BusySplit
@return:
 jmp $80B7
BusySplit:
 ; Sprite-zero's hit flag survives vblank and clears on the pre-render
 ; line. A busy NMI reaches this path earlier than the normal game loop.
 lda $2002
 and #$40
 bne BusySplit
@hit:
 lda $2002
 and #$40
 beq @hit
 ; Same sprite-zero delay and hardware writes as the native HUD split.
 jsr BusyDelay
 lda $2002
 ldx #0
BusyHud:
 stx $2005
 stx $2005
 lda G_LAST_CTRL
 and #$FC
 sta $2000
 ldy #2
 jmp $8A9E
BusyDelay:
 bit $00
 bit $00
 ldx #$59
@delay:
 dex
 bne @delay
 rts

PaletteGate:
 jsr $8A51
 lda $00
 cmp #2
 beq @play
 cmp #5
 bne @done
@play:
 ldx #3
 ldy $18
 beq @mario
 ldx #0
 lda #$1A
 bne @write
@mario:
 ; Restore the original native sprite shade when Mario's turn returns.
 lda $879B
@write:
 stx G_PLAYER_ATTR
 tax
 bit $2002
 lda #$3F
 sta $2006
 lda #$11
 sta $2006
 stx $2007
@done:
 rts

InputGate:
 jsr $81BF
 lda $00
 cmp #5
 beq @float
 lda #0
 sta G_INV
 sta G_ARMED
 sta G_SEQUENCE
 sta G_SEQUENCE+1
 lda $00
 cmp #2
 bne ResetFloat
@float:
 lda $1B
 cmp #$80
 bcc ResetFloat
 and #$70
 bne ResetFloat
 lda $0100
 cmp #1
 beq FloatDone
ResetFloat:
 lda #0
 sta G_FLOAT_READY
 sta G_FLOAT_VY
 sta G_EXTRA_KIND
 sta G_EXTRA_KIND+1
 sta G_EXTRA_KIND+2
 sta G_EXTRA_KIND+3
 sta G_EXTRA_KIND+4
 sta G_EXTRA_KIND+5
FloatDone: rts

; Replace only the native vertical movement. Horizontal speed, weapon input,
; native death/terrain rules, and the option-history ring remain native.
FloatGate:
 jsr FloatStep
 lda #1
 sta $9B
 lda $0320
 cmp G_FLOAT_OLD_Y
 beq @input
 ldy #2
 bcs :+
 ldy #3
:
 sty $9B
 jmp $A086
@input:
 lda $07,x
 and #$0F
 bne :+
 jmp $A0AD
:
 jmp $A086
FloatStep:
 lda G_FLOAT_READY
 bne @ready
 lda #0
 sta G_FLOAT_VY
 sta $0340
 lda #1
 sta G_FLOAT_READY
@ready:
 lda $0320
 sta G_FLOAT_OLD_Y
 ; Speed capsules improve lift as well as the native horizontal speed.
 lda $40
 cmp #8
 bcc :+
 lda #8
:
 asl a
 asl a
 clc
 adc #16
 sta G_FLOAT_CAP
 lda $07,x
 and #8
 beq @fall
 lda G_FLOAT_VY
 sec
 sbc #2
 bpl @velocity
 clc
 adc G_FLOAT_CAP
 bcs @keepLift
 lda #0
 sec
 sbc G_FLOAT_CAP
 jmp @velocity
@keepLift:
 lda G_FLOAT_VY
 sec
 sbc #2
 jmp @velocity
@fall:
 inc G_FLOAT_VY
 lda $07,x
 and #4
 beq @gentle
 inc G_FLOAT_VY
 lda #24
 bne @fallCap
@gentle:
 lda #16
@fallCap:
 sta G_FLOAT_DELTA
 lda G_FLOAT_VY
 bmi @velocity
 cmp G_FLOAT_DELTA
 bcc @velocity
 lda G_FLOAT_DELTA
@velocity:
 sta G_FLOAT_VY
 ; Signed eighth-pixel integration, sharing the native Y fraction.
 cmp #$80
 ror a
 cmp #$80
 ror a
 cmp #$80
 ror a
 sta G_FLOAT_DELTA
 lda G_FLOAT_VY
 and #7
 ror a
 ror a
 ror a
 ror a
 and #$E0
 clc
 adc $0340
 sta $0340
 lda G_FLOAT_DELTA
 adc $0320
 cmp #16
 bcc @top
 cmp #188
 bcs @bottom
 sta $0320
 rts
@top:
 lda #16
 bne @clamp
@bottom:
 lda #188
@clamp:
 sta $0320
 lda #0
 sta G_FLOAT_VY
 sta $0340
 rts

PauseGate:
 ; Runs after the native frame, including native pause/resume handling.
 jsr $8641
 jmp CheatInput
CheatInput:
 lda $15
 bne @paused
 lda G_ARMED
 beq @clear
 lda #0
 sta G_ARMED
 lda #1
 sta G_INV
 lda #$36
 jsr $EC1E
@clear:
 lda #0
 sta G_SEQUENCE
 sta G_SEQUENCE+1
 rts
@paused:
 ldx #0
@player:
 lda $07,x
 and #$0F
 cmp #8
 bne @wrong
 lda $05,x
 and #$C0
 beq @next
 ldy G_SEQUENCE,x
 cmp CheatButtons,y
 bne @wrong
 inc G_SEQUENCE,x
 iny
 cpy #4
 bne @next
 lda #1
 sta G_ARMED
@wrong:
 lda #0
 sta G_SEQUENCE,x
@next:
 inx
 cpx #2
 bne @player
 rts
CheatButtons: .byte $40,$80,$80,$40

FireGate:
 lda $44
 cmp #2
 beq @double
 ldx $44
 lda $A0E0,x
 jmp $A0EE
@double:
 jsr DoubleFire
 jmp $A16F
DoubleFire:
 lda #6
 sta $98
 lda #1
 sta $99
 lda #$24
 sta $9C
 ldx $18
 lda $05,x
 and #$80
 sta $9A
 lda $07,x
 and #$80
 sta $9B
 ldx $45
@owner:
 lda $9A
 bne @forward
 lda $03A3,x
 bne @tickForward
 lda $9B
 beq @up
@forward:
 lda $0123,x
 beq @nativeForward
 lda G_EXTRA_KIND,x
 bne @tickForward
 txa
 tay
 lda #6
 jsr SpawnExtra
 jmp @reloadForward
@nativeForward:
 jsr $A235
@reloadForward:
 lda $35
 sta $03A3,x
 jmp @up
@tickForward:
 lda $03A3,x
 beq @up
 dec $03A3,x
@up:
 lda $9A
 bne @upward
 lda $03A6,x
 bne @tickUp
 lda $9B
 beq @missile
@upward:
 lda $0126,x
 beq @nativeUp
 lda G_EXTRA_KIND+3,x
 bne @tickUp
 txa
 clc
 adc #3
 tay
 lda #$24
 jsr SpawnExtra
 jmp @reloadUp
@nativeUp:
 jsr $A250
@reloadUp:
 lda $35
 sta $03A6,x
 jmp @missile
@tickUp:
 lda $03A6,x
 beq @missile
 dec $03A6,x
@missile:
 lda $41
 beq @next
 lda $0129,x
 bne @next
 lda $9B
 beq @next
 jsr $A26B
@next:
 dex
 jpl @owner
 rts
SpawnExtra:
 sta G_EXTRA_KIND,y
 lda $0360,x
 sta G_EXTRA_X,y
 lda $0320,x
 sta G_EXTRA_Y,y
 lda #0
 sta G_EXTRA_FRAC,y
 sta G_EXTRA_SUB,y
 lda #8
 sta G_EXTRA_VY,y
 lda G_EXTRA_KIND,y
 cmp #$24
 bne :+
 lda #2
 sta G_EXTRA_SUB,y
 lda #$F0
 sta G_EXTRA_VY,y
:
 jmp $A266

; Six extra virtual slots give each origin a second forward and upward shot.
; Swap into the original slots only while running shared physics/collisions.
SwapShots:
 ldx #5
@slot:
 .macro Exchange native,extra
  lda native,x
  ldy extra,x
  sta extra,x
  tya
  sta native,x
 .endmacro
 Exchange $0123,G_EXTRA_KIND
 Exchange $0163,G_EXTRA_SUB
 Exchange $0363,G_EXTRA_X
 Exchange $0323,G_EXTRA_Y
 Exchange G_FIRE_VY,G_EXTRA_VY
 Exchange G_FIRE_FRAC,G_EXTRA_FRAC
 dex
 bpl @slot
 rts
HaveExtra:
 lda G_EXTRA_KIND
 ora G_EXTRA_KIND+1
 ora G_EXTRA_KIND+2
 ora G_EXTRA_KIND+3
 ora G_EXTRA_KIND+4
 ora G_EXTRA_KIND+5
 rts
CombatGate:
 jsr EarlyCombat
 jmp LateCombat
EarlyCombat:
 ; Build the active collision candidates once for all fifteen logical
 ; projectiles instead of testing every empty enemy and bullet slot again.
 jsr BuildTargets
 jsr BuildArms
 lda #$FF
 sta G_SWEEP_END
 ldx #8
 jsr ShotSweep
 lda #0
 sta G_TERRAIN_PENDING
 sta G_TERRAIN_DEFER
 ; Keep quiet scenes at full speed; only a crowded extra-shot wave needs
 ; the terrain work moved out of the pre-split window.
 jsr HaveExtra
 beq :+
 lda G_TARGET_COUNT
 cmp #8
 bcc :+
 lda #1
 sta G_TERRAIN_DEFER
:
 lda $5C
 cmp #2
 bcs ContactDone
 jsr $C0C7
ContactDone:
 lda #0
 sta G_TERRAIN_DEFER
 jsr HaveExtra
 sta G_EXTRA_PENDING
 lda #1
 sta G_COMBAT_PENDING
@done: rts
FinishCombat:
 jsr LateCombat
 jmp $9C45
LateCombat:
 lda G_COMBAT_PENDING
 beq LateCombatDone
 lda #0
 sta G_COMBAT_PENDING
 lda G_TERRAIN_PENDING
 beq :+
 lda #0
 sta G_TERRAIN_PENDING
 jsr NativeTerrain
:
 lda G_EXTRA_PENDING
 beq LateCombatDone
 lda #0
 sta G_EXTRA_PENDING
 jmp ExtraSweep
LateCombatDone: rts
TerrainTail:
 ; Player/enemy/bullet contact remains after every native shot. Defer only
 ; the remaining terrain sweeps, which can run safely after the HUD split.
 lda G_TERRAIN_DEFER
 beq NativeTerrain
 lda #1
 sta G_TERRAIN_PENDING
 rts
NativeTerrain:
 ldx #5
 stx $A8
 jmp $C2C8
TerrainGate:
 ; Fireball physics already performed this exact terrain probe and bounce.
 ; Keep the native laser's destructible-terrain path.
 lda $0163,x
 cmp #1
 beq @laser
 lda #0
 rts
@laser:
 jmp $C3AF
BuildTargets:
 lda #$FF
 sta G_MIN_X
 lda #0
 sta G_MAX_X
 ldy #0
 ldx #0
@target:
 lda $030C,x
 bpl @bullet
 txa
 pha
 lda $0460,x
 tax
 lda $BFDE,x
 sta G_TMP
 pla
 tax
 lda G_TMP
 sta G_TARGET_HEIGHT,x
 lda $036C,x
 jsr TargetBounds
 lda $0316,x
 beq @add
 lda $0376,x
 jsr TargetBounds
 jmp @add
@bullet:
 lda $0316,x
 beq @next
 lda $0376,x
 jsr TargetBounds
@add:
 txa
 sta G_TARGETS,y
 iny
@next:
 inx
 cpx #10
 bne @target
 sty G_TARGET_COUNT
 rts
TargetBounds:
 cmp G_MIN_X
 bcs :+
 sta G_MIN_X
:
 cmp G_MAX_X
 bcc :+
 sta G_MAX_X
:
 rts
BuildArms:
 lda #0
 sta G_ARM_COUNT
 lda $19
 cmp #4
 bne @done
 lda #0
 sta G_ARM_OWNER
 ldy #0
@arm:
 ldx G_ARM_OWNER
 lda $0600,x
 beq @nextArm
 lda #0
 sta G_ARM_SEG
@segment:
 txa
 sta G_ARM_PART,y
 lda $0618,x
 sta G_ARM_X,y
 lda $0620,x
 sta G_ARM_Y,y
 lda G_ARM_OWNER
 sta G_ARM_ID,y
 iny
 inx
 inc G_ARM_SEG
 lda G_ARM_SEG
 cmp #6
 bne @segment
@nextArm:
 lda G_ARM_OWNER
 clc
 adc #$30
 sta G_ARM_OWNER
 cmp #$C0
 bne @arm
 sty G_ARM_COUNT
@done: rts
; Native damage dispatch, with inactive collision slots removed up front.
; Player contact and missile processing still run exactly once per update.
ExtraSweep:
 lda #$FF
 sta G_SWEEP_END
 ldx #5
 jmp ExtraShotSweep
.macro Sweep name,kind,sub,xpos,ypos,hit,bullet,arms
name:
 stx $A8
@shot:
 ldx $A8
 lda kind,x
 jeq @nextShot
 ldy sub,x
 lda xpos,x
 clc
 adc $BFCE,y
 bcc :+
 lda #$FF
:
 sta $A0
 lda $BFD2,y
 sta $A3
 lda ypos,x
 clc
 adc $BFD6,y
 sta $A1
 ; Most shots are far from the current enemy wave. Reject the whole
 ; target range, including the native unsigned wrap case, before scanning.
 lda $A0
 cmp G_MAX_X
 bcc @lowerBound
 sbc G_MAX_X
 cmp $A3
 bcs @arms
@lowerBound:
 lda $A0
 cmp G_MIN_X
 bcs @candidates
 lda G_MAX_X
 clc
 adc $A3
 bcc @arms
@candidates:
 ldx G_TARGET_COUNT
 beq @arms
@enemy:
 dex
 bmi @arms
 ldy G_TARGETS,x
 lda $030C,y
 bpl @bullet
 lda $A0
 sec
 sbc $036C,y
 cmp $A3
 bcs @bullet
 lda $A1
 sbc $032C,y
 cmp G_TARGET_HEIGHT,y
 bcs @bullet
 stx G_TARGET_INDEX
 sty $A9
 jsr hit
 ldx $A8
 lda kind,x
 beq @nextShot
 ldx G_TARGET_INDEX
 ldy G_TARGETS,x
@bullet:
 lda $0316,y
 beq @enemy
 lda $A1
 sec
 sbc $0336,y
 cmp #$10
 bcs @enemy
 lda $A0
 sbc $0376,y
 cmp $A3
 bcs @enemy
 stx G_TARGET_INDEX
 sty $A9
 jsr bullet
 ldx $A8
 lda kind,x
 beq @nextShot
 ldx G_TARGET_INDEX
 jmp @enemy
@arms:
 lda $19
 cmp #4
 bne @nextShot
 ldx $A8
 lda kind,x
 beq @nextShot
 jsr arms
@nextShot:
 dec $A8
 lda $A8
 cmp G_SWEEP_END
 jne @shot
 rts
.endmacro
Sweep ShotSweep,$0123,$0163,$0363,$0323,$C055,$BF90,NativeArms
Sweep ExtraShotSweep,G_EXTRA_KIND,G_EXTRA_SUB,G_EXTRA_X,G_EXTRA_Y,ExtraHit,ExtraBullet,ExtraArms
ExtraHit:
 jsr SwapOne
 jsr $C055
 jmp SwapOne
ExtraBullet:
 jsr SwapOne
 jsr $BF90
 jmp SwapOne
ExtraArms:
 ldx G_ARM_COUNT
 jmp ExtraArmSweep
NativeArms:
 ldx G_ARM_COUNT
 jmp NativeArmSweep
.macro Arms name,hit
name:
 dex
 bmi @done
 lda $A0
 sec
 sbc G_ARM_X,x
 cmp $A3
 bcs name
 lda $A1
 sbc G_ARM_Y,x
 cmp #10
 bcs name
 ldy G_ARM_ID,x
 lda $0600,y
 beq name
 sty $A9
 lda G_ARM_PART,x
 sec
 sbc G_ARM_ID,x
 sta $AB
 jmp hit
@done: rts
.endmacro
Arms NativeArmSweep,$BF31
Arms ExtraArmSweep,ExtraArmHit
ExtraArmHit:
 jsr SwapOne
 jsr $BF31
 jmp SwapOne
SwapOne:
 ldx $A8
 ; Hit dispatch reads only the slot kind/sub/X/Y; physics remains in its
 ; own pool. Exchange just the colliding shot, rather than all six twice.
 Exchange $0123,G_EXTRA_KIND
 Exchange $0163,G_EXTRA_SUB
 Exchange $0363,G_EXTRA_X
 Exchange $0323,G_EXTRA_Y
 ldy $A9
 rts

; Normal shots are falling, bouncing Mario fireballs. Keep native shot slots,
; enemy/boss damage, reload, Options and the power-up bar.
SpawnAEnd:
 lda #8
 sta G_FIRE_VY,x
 lda #0
 sta G_FIRE_FRAC,x
 jmp $A266
SpawnBEnd:
 sta $0166,x
 lda #8
 ldy $44
 cpy #2
 bne :+
 lda #$F0
:
 sta G_FIRE_VY+3,x
 lda #0
 sta G_FIRE_FRAC+3,x
 jmp $A266
FireLoop:
 jsr StepShots
 jsr StepExtra
@done:
 ldx #6
 rts
.macro ShotPhysics name,kind,sub,xpos,ypos,vy,frac,probe
name:
 ldx #0
@shot:
 lda kind,x
 jeq @next
 lda sub,x
 cmp #1
 jeq @laser
 ; Horizontal speed is independent of gravity.
 lda xpos,x
 clc
 adc #4
 jcs @free
 cmp #$F8
 jcs @free
 sta xpos,x
 lda ypos,x
 sta G_OLD_Y
 lda vy,x
 cmp #$10
 beq :+
 inc vy,x
:
 lda vy,x
 ; Arithmetic shift converts signed quarter-pixel speed to whole pixels.
 cmp #$80
 ror a
 cmp #$80
 ror a
 sta G_DELTA
 lda vy,x
 and #3
 ror a
 ror a
 ror a
 and #$C0
 clc
 adc frac,x
 sta frac,x
 lda G_DELTA
 adc ypos,x
 cmp #8
 bcc @free
 cmp #200
 jcs @free
 sta ypos,x
 ; Stage 5's moving arms use native object collisions, no terrain map.
 lda $19
 cmp #4
 beq @next
 stx G_FIRE_SLOT
 jsr probe
 pha
 ldx G_FIRE_SLOT
 pla
 beq @next
 ; A downward hit bounces; a wall/ceiling hit extinguishes the fireball.
 lda vy,x
 bmi @free
 lda G_OLD_Y
 sta ypos,x
 stx G_FIRE_SLOT
 jsr probe
 pha
 ldx G_FIRE_SLOT
 pla
 bne @free
 lda #$F0
 sta vy,x
 lda #0
 sta frac,x
 beq @next
@laser:
 lda xpos,x
 clc
 adc #12
 jcs @free
 cmp #$F0
 jcs @free
 sta xpos,x
 bcc @next
@free:
 lda #0
 sta kind,x
 sta sub,x
@next:
 inx
 cpx #6
 jcc @shot
 rts
.endmacro
ShotPhysics StepShots,$0123,$0163,$0363,$0323,G_FIRE_VY,G_FIRE_FRAC,$C3AF
ShotPhysics StepExtra,G_EXTRA_KIND,G_EXTRA_SUB,G_EXTRA_X,G_EXTRA_Y,G_EXTRA_VY,G_EXTRA_FRAC,ExtraTerrain
ExtraTerrain:
 lda G_EXTRA_Y,x
 sta $A5
 lda G_EXTRA_X,x
 sta $A4
 jmp $C3D3

DeathGate:
 lda G_INV
 beq @native
 rts
@native:
 lda $1B
 cmp #$81
 jmp $C1DA

DrawGate:
 lda #0
 sta G_DRAW
 sta G_READY
 lda $00
 cmp #2 ; Native attract-mode gameplay.
 beq @play
 cmp #5
 beq @play
 jsr $8B10
 jmp $8BAB
@play:
 lda $0100
 cmp #1
 bne @draw
 lda #1
 sta G_DRAW
 lda $0360
 sta G_X
 lda $0320
 sta G_Y
@draw:
 ; Build one contiguous hardware buffer. Avoid drawing, hiding and then
 ; copying a second native buffer before the time-critical status-bar split.
 jsr Compose
 lda #$FF
 sta $37
 jmp Swim
Swim:
 lda G_DRAW
 bne @animate
 lda #0
 sta G_SWIM_TIMER
 sta G_SWIM_PHASE
 beq @banks
@animate:
 lda $15
 bne @banks
 inc G_SWIM_TIMER
 lda G_SWIM_TIMER
 cmp #8
 bcc @banks
 lda #0
 sta G_SWIM_TIMER
 inc G_SWIM_PHASE
 lda G_SWIM_PHASE
 cmp #3
 bcc @banks
 lda #0
 sta G_SWIM_PHASE
@banks:
 lda G_SWIM_PHASE
 asl a
 asl a
 sta G_BANKS
 ora #2
 sta G_BANKS+1
 lda G_BANKS
 ora #1
 sta G_BANKS+2
 ora #2
 sta G_BANKS+3
 rts
BlankGate: rts
Compose:
 ; Sprite zero's timing marker must remain at hardware slot zero.
 lda #0
 ldx #3
 ldy $1F
 beq @marker
 ldx #7
 dey
 bne :+
 ldy #2
 sty $1F
 bne @marker
:
 lda #1
@marker:
 sta $1E
 ldy #3
@zero:
 lda $8B08,x
 sta $0200,y
 sta G_BUFFER,y
 dex
 dey
 bpl @zero
 lda #4
 sta G_OAM
 lda G_DRAW
 beq @death
 lda #0
 sta G_OWNER
@body:
 ldx G_OWNER
 lda $0120,x
 beq @nextBody
 lda $0360,x
 sta G_X
 lda $0320,x
 sta G_Y
 jsr DrawMario
@nextBody:
 inc G_OWNER
 lda G_OWNER
 cmp #3
 bne @body
 ; Preserve the native barrier animation and placement around the player.
 ldy $46
 beq @others
 lda $1B
 and #$70
 bne @others
 ldx #0
 jsr ActorPosition
 cpy #1
 bne :+
 lda #3
 sta $9E
:
 lda $02
 lsr a
 lsr a
 and #3
 clc
 adc #$5A
 jsr DrawMeta
 jmp @others
@death:
 ldx #0
@deathActor:
 stx G_ACTOR
 jsr DrawActor
 ldx G_ACTOR
 inx
 cpx #3
 bne @deathActor
@others:
 lda #FIRE_TILE_0
 sta G_FIRE_TILE
 lda $02
 and #4
 beq :+
 lda #FIRE_TILE_1
 sta G_FIRE_TILE
:
 ldy #0
@extra:
 lda G_EXTRA_KIND,y
 beq @skipExtra
 ldx G_OAM
 beq @skipExtra
 lda G_EXTRA_Y,y
 clc
 adc #FIRE_DY
 cmp #212
 bcs @skipExtra
 sta G_BUFFER,x
 lda G_FIRE_TILE
 sta G_BUFFER+1,x
 lda #3
 sta G_BUFFER+2,x
 lda G_EXTRA_X,y
 clc
 adc #FIRE_DX
 sta G_BUFFER+3,x
 txa
 clc
 adc #4
 sta G_OAM
@skipExtra:
 iny
 cpy #6
 bne @extra
 lda #3
 sta G_ACTOR
@weapon:
 ldx G_ACTOR
 jsr DrawActor
 inc G_ACTOR
 lda G_ACTOR
 cmp #12
 bne @weapon
 ; Rotate enemy/bullet order so overloaded scanlines share sprite priority.
 inc G_ROTATION
 lda G_ROTATION
 cmp #20
 bcc :+
 lda #0
 sta G_ROTATION
:
 clc
 adc #12
 sta G_ACTOR
 lda #20
 sta G_COUNT
@enemy:
 ldx G_ACTOR
 jsr DrawEnemy
 inc G_ACTOR
 lda G_ACTOR
 cmp #32
 bne :+
 lda #12
 sta G_ACTOR
:
 dec G_COUNT
 bne @enemy
 lda $19
 cmp #4
 bne @hideRest
 jsr DrawArms
@hideRest:
 ldx G_OAM
 beq @ready
 lda #$F4
@hide:
 sta G_BUFFER,x
 inx
 inx
 inx
 inx
 bne @hide
@ready:
 lda #1
 sta G_READY
 rts
DrawMario:
 ldx G_OAM
 .repeat 2,row
 lda G_Y
 sec
 sbc #9
 clc
 adc #row*16
 cmp #212
 bcs :+
 sta G_BUFFER,x
 sta G_BUFFER+4,x
 .if row=0
 lda #MARIO_TILE_0
 .else
 lda #MARIO_TILE_2
 .endif
 sta G_BUFFER+1,x
 .if row=0
 lda #MARIO_TILE_1
 .else
 lda #MARIO_TILE_3
 .endif
 sta G_BUFFER+5,x
 lda G_PLAYER_ATTR
 sta G_BUFFER+2,x
 sta G_BUFFER+6,x
 lda G_X
 sec
 sbc #4
 sta G_BUFFER+3,x
 clc
 adc #8
 sta G_BUFFER+7,x
 txa
 clc
 adc #8
 tax
:
 .endrepeat
 stx G_OAM
 rts
ActorPosition:
 lda $0180,x
 sta $9E
 lda $0320,x
 sta $99
 lda $0360,x
 sta $9A
 rts
DrawActor:
 lda $0120,x
 beq DrawNothing
 cmp #6
 beq DrawFire
 cmp #$24
 beq DrawFire
DrawPosition:
 lda $0180,x
 sta $9E
 lda $0320,x
 sta $99
 lda $0360,x
 sta $9A
 lda $0120,x
 jmp DrawMeta
DrawFire:
 ldy G_OAM
 beq DrawNothing
 lda $0320,x
 clc
 adc #FIRE_DY
 sta G_BUFFER,y
 lda G_FIRE_TILE
 sta G_BUFFER+1,y
 lda $0180,x
 ora #3
 sta G_BUFFER+2,y
 lda $0360,x
 clc
 adc #FIRE_DX
 sta G_BUFFER+3,y
 tya
 clc
 adc #4
 sta G_OAM
DrawNothing: rts
DrawEnemy:
 lda $0120,x
 bne DrawPosition
 rts
; Native metasprite format, coordinates, attributes and X overflow clipping.
; Write directly into the final DMA buffer rather than scattering and packing.
DrawMeta:
 asl a
 bcs @high
 tay
 ldx $8D9E,y
 lda $8D9F,y
 jmp @pointer
@high:
 tay
 ldx $8E9E,y
 lda $8E9F,y
@pointer:
 stx $A0
 sta $A1
 ldy #0
 lda ($A0),y
 beq @done
 sta $9B
 iny
@sprite:
 ldx G_OAM
 beq @done
 lda ($A0),y
 iny
 clc
 adc $99
 sta G_BUFFER,x
 lda ($A0),y
 iny
 sta G_BUFFER+1,x
 lda ($A0),y
 iny
 ora $9E
 sta G_BUFFER+2,x
 lda ($A0),y
 clc
 bmi @negative
 adc $9A
 bcs @skip
 bcc @write
@negative:
 adc $9A
@write:
 sta G_BUFFER+3,x
 txa
 clc
 adc #4
 sta G_OAM
@skip:
 iny
 dec $9B
 bne @sprite
@done: rts
DrawArms:
 ; Preserve the native arm tiles, palettes and head flips, while drawing
 ; directly into the same final buffer as the rest of the scene.
 lda #$90
 sta $A8
@arm:
 ldx $A8
 lda $0600,x
 beq @nextArm
 lda $0615,x
 lsr a
 lsr a
 and #$0F
 tax
 lda $8BF2,x
 sta $AB
 txa
 lsr a
 lsr a
 tax
 lda $8C02,x
 sta $AC
 ldy $A8
 lda #5
 sta $AA
@segment:
 ldx G_OAM
 beq @done
 lda $0618,y
 beq @skip
 cmp #$F4
 bcs @skip
 sta G_BUFFER+3,x
 lda $0620,y
 sta G_BUFFER,x
 lda $AA
 beq @head
 lda #$F7
 sta G_BUFFER+1,x
 lda $AA
 cmp #3
 bne @body
 lda #2
 bne @attribute
@body:
 lda #1
@attribute:
 sta G_BUFFER+2,x
 jmp @advance
@head:
 lda $AB
 sta G_BUFFER+1,x
 lda $AC
 sta G_BUFFER+2,x
 bpl @advance
 lda G_BUFFER,x
 sec
 sbc #8
 sta G_BUFFER,x
@advance:
 txa
 clc
 adc #4
 sta G_OAM
@skip:
 iny
 dec $AA
 bpl @segment
@nextArm:
 lda $A8
 sec
 sbc #$30
 sta $A8
 bpl @arm
@done: rts
MarioDX: .byte 0,8,0,8
MarioDY: .byte 0,0,16,16
MarioTiles: .byte MARIO_TILE_0,MARIO_TILE_1,MARIO_TILE_2,MARIO_TILE_3
FireFrame0: .byte 1,FIRE_DY,FIRE_TILE_0,3,FIRE_DX
FireFrame1: .byte 1,FIRE_DY,FIRE_TILE_1,3,FIRE_DX
.export FireFrame0,FireFrame1
DmaGate:
 ldy #2
 lda G_READY
 beq :+
 ldy #$71
:
 sty $4014
 rts
.assert * <= $7000,error,"CHR-loaded code exceeds bootstrap copy"

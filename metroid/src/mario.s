.setcpu "6502"
.macpack longbranch
.include "state.inc"
.include "native.inc"
.export Boot,BeforeHandler,Horizontal,Vertical,Land,Ceiling,DrawGate,ContactGate,FireMove,FireInit
.export Init,Step,X_Physics,GetPlayerAnimSpeed,ImposeFriction,M_MAGIC,M_STATE,M_SMB_X_SPEED,M_VY,M_POSE,M_NATIVE
.export NmiEnter,NmiLeave
.export DrawMario,M_DRAW_FIRE
.export WallGate,Projectiles,EnemyFireCheck,MellowFireCheck,MellowContactGate
.segment "BOOT"
Boot:
 ; The native startup has already cleared all RAM, with rendering/NMI off.
 lda #8
 jsr N_MMCWritePrgBank
 lda #$80
 sta $01
 lda #$74
 sta $03
 lda #0
 sta $00
 sta $02
 ldy #0
@page:
 lda ($00),y
 sta ($02),y
 iny
 bne @page
 inc $01
 inc $03
 lda $03
 cmp #$78
 bne :+
 lda #$79
 sta $03
:
 cmp #$80
 bne @page
 lda #0
 jsr N_MMCWritePrgBank
 jmp StartupTail
.segment "A"
Init:
 lda M_MAGIC
 cmp #$4D
 beq @done
 lda #0
 ldx #$3F
@clear: sta BASE,x
 dex
 bpl @clear
 lda #1
 sta M_FACING
 sta M_MOVING_DIR
 sta M_AREA_TYPE
 lda #8
 sta M_ENGINE_MODE
 lda #$70
 sta M_FALL_FORCE
 lda #$4D
 sta M_MAGIC
@done: rts
BeforeHandler:
 jsr Step
 jmp N_GoSamusHandler
Step:
 jsr Init
 lda M_HELD
 sta M_PREV
 lda $14
 sta M_HELD
 lda $030D
 sta M_PREV_Y
 lda M_THROW
 beq :+
 dec M_THROW
:
 lda M_GRACE
 beq :+
 dec M_GRACE
:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda $0300
 cmp #$FF
 beq @allowed
 cmp #5
 jeq @script
 cmp #7
 jcs @script
@allowed:
 lda $58
 jne @script
 lda $030A
 and #$20
 jne @script
 lda $70
 cmp #32
 jcs @script
 lda M_NATIVE
 beq @own
 lda $0308
 sta M_VY
 lda $0312
 sta M_VY_FRAC
 lda $0310
 sta M_Y_FRAC
 lda #0
 ldx $0314
 beq :+
 lda #2
:
 sta M_STATE
@own:
 lda #0
 sta M_NATIVE
 sta M_SMALL
 lda $0300
 cmp #3
 bne :+
 inc M_SMALL
:
 lda M_SMALL
 cmp M_OLD_SMALL
 beq @support
 sta M_OLD_SMALL
 lda #0
 sta M_Y_FRAC
 lda $0308
 sta M_VY
 lda $0312
 sta M_VY_FRAC
@support:
 lda $0300
 cmp #$FF
 beq @input
 lda M_SMALL
 beq @testSupport
 lda #0
 ldx $0314
 beq :+
 lda #2
:
 sta M_STATE
@testSupport:
 lda M_STATE
 bne @input
 jsr Support
 bcc @input
 lda #2
 sta M_STATE
 lda M_FALL_FORCE
 sta M_GRAVITY
@input:
 lda M_HELD
 and #3
 sta M_INPUT_DIR
 lda M_STATE
 bne :+
 lda M_HELD
 and #4
 beq :+
 lda #0
 sta M_INPUT_DIR
:
 jsr Jump
 lda #3
 sta M_COLL_DIR
 jsr X_Physics
 lda M_STATE
 bne @air
 jsr GetPlayerAnimSpeed
 lda M_INPUT_DIR
 beq @friction
 sta M_FACING
 bne @friction
@air:
 lda M_INPUT_DIR
 beq @done
@friction:
 jsr ImposeFriction
@done: rts
@script:
 lda #1
 sta M_NATIVE
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_X_FRAC
 sta M_GRACE
 rts
Support:
 lda $030D
 clc
 adc $0301
 and #7
 bne @entities
 jsr N_ObjectCheckMoveDown
 bcc @ground
@entities:
 jsr N_SamusCollisionWithSolidEntities
 lda $0307
 ora $7D
 beq @air
@ground: clc
 rts
@air: sec
 rts
Jump:
 lda M_STATE
 bne @done
 lda M_SMALL
 bne @done ; native A/Up unroll; bombs preserve Morph Ball traversal.
 lda $12
 and #$80
 beq @done
 ldy #0
 lda M_SMB_X_ABS
 cmp #9
 bcc @select
 iny
 cmp #$10
 bcc @select
 iny
 cmp #$19
 bcc @select
 iny
 cmp #$1C
 bcc @select
 iny
@select:
 lda JumpForce,y
 sta M_GRAVITY
 lda FallForce,y
 sta M_FALL_FORCE
 lda JumpSpeed,y
 ldx $6878
 ; High Jump Boots intentionally extend Mario's launch; gear remains meaningful.
 txa
 and #2
 beq @regular
 lda JumpSpeed,y
 sec
 sbc #1
 bne @launch
@regular:
 lda JumpSpeed,y
@launch:
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta M_Y_FRAC
 lda $030D
 sta M_JUMP_ORIGIN
 lda #1
 sta M_STATE
@done: rts
JumpForce: .byte $20,$20,$1E,$28,$28
FallForce: .byte $70,$70,$60,$90,$90
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB
Horizontal:
 lda M_NATIVE
 beq @custom
 lda $0316
 jmp N_HorzAccelerate+3
@custom:
 lda M_SMB_X_SPEED
 asl
 asl
 asl
 asl
 clc
 adc M_X_FRAC
 sta M_X_FRAC
 php
 lda M_SMB_X_SPEED
 lsr
 lsr
 lsr
 lsr
 cmp #8
 bcc :+
 ora #$F0
:
 sta M_TMP
 sta $0309
 plp
 lda M_TMP
 adc #0
 sta $00
 sta M_DX
 ldx #1
 lda M_SMB_X_SPEED
 beq @facing
 bpl :+
 inx
:
 stx M_MOVING_DIR
@facing:
 lda M_FACING
 sec
 sbc #1
 sta $4D
 rts
.include "smb-land.inc"
.segment "B"
NmiEnter:
 php
 pha
 txa
 pha
 tya
 pha
 lda $00
 pha
 lda $01
 pha
 lda #0
 sta M_NMI_DEFER
 ; Do not interleave a vblank mirroring write with a foreground MMC1
 ; serial transaction. The interrupted PC is above six saved bytes.
 tsx
 lda $0109,x
 cmp #$C4
 beq @bankC4
 cmp #$C5
 bne @ready
 lda $0108,x
 cmp #$10
 bcc @defer
 bcs @ready
@bankC4:
 lda $0108,x
 cmp #$B6
 bcc @ready
@defer:
 lda $1A
 sta M_NMI_STATUS
 lda #1
 sta M_NMI_DEFER
 sta $1A
@ready:
 jmp N_NMI+6
NmiLeave:
 lda M_NMI_DEFER
 beq :+
 lda M_NMI_STATUS
 sta $1A
:
 pla
 sta $01
 pla
 sta $00
 pla
 tay
 pla
 tax
 pla
 plp
 rti
StartupTail:
 ; Native startup tail moved verbatim in behavior to make room for the loader.
 lda #$0E
 sta $25
 lda #0
 sta $28
 ldy #0
 sty $FD
 sty $FC
 sty $2005
 sty $2005
 iny
 sty $1D
 jsr N_ClearNameTables
 jsr N_EraseAllSprites
 lda #$90
 sta $2000
 sta $FF
 lda #2
 sta N_PPUMASK_ZP
 lda #$47
 sta $FA
 jsr N_PrepVertMirror
 lda #0
 sta $4011
 lda #$0F
 sta $4015
 ldy #0
 sty $1F
 sty $1E
 lda #$11
 sta N_RandomNumber1
 lda #$FF
 sta N_RandomNumber2
 iny
 sty N_BankSwitchPending
 jsr N_CheckBankSwitch
 jmp N_MainLoop_loop_waitNMIEnd
Vertical:
 lda M_NATIVE
 bne @native
 lda M_SMALL
 beq @custom
@native:
 lda $0314
 jmp N_VertAccelerate+3
@custom:
 lda M_STATE
 bne @air
 lda #0
 sta $0308
 sta $0312
 sta $0314
 sta $00
 rts
@air:
 lda M_VY
 bpl @fall
 lda M_HELD
 and #$80
 and M_PREV
 bne @integrate
 lda M_JUMP_ORIGIN
 sec
 sbc $030D
 cmp #1
 bcc @integrate
@fall:
 lda M_FALL_FORCE
 sta M_GRAVITY
@integrate:
 lda M_VY
 sta $0308
 lda M_VY_FRAC
 sta $0312
 clc
 adc M_Y_FRAC
 sta M_Y_FRAC
 lda M_VY
 adc #0
 sta M_DY
 sta $00
 lda #$1A
 sta $0314
 lda M_VY_FRAC
 clc
 adc M_GRAVITY
 sta M_VY_FRAC
 lda M_VY
 adc #0
 sta M_VY
 bmi @done
 cmp #4
 bcc @done
 lda M_VY_FRAC
 cmp #$80
 bcc @done
 lda #4
 sta M_VY
 lda #0
 sta M_VY_FRAC
@done: rts
Land:
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 jmp N_StopVertMovement
Ceiling:
 jsr N_MoveSamusUp
 bcs @done
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta M_Y_FRAC
 lda M_FALL_FORCE
 sta M_GRAVITY
@done: rts
WallGate:
 bcs @moved
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_X_FRAC
 sta M_DX
 lda #1
 sta N_ObjectCounter
 jmp N_CheckStopHorzMvmt+6
@moved: rts
DrawGate:
 ; Enemy rendering and object rendering share this final entry. Their slot
 ; numbers overlap: zero is also the enemy scratch slot, and $50 is a real
 ; enemy slot. Identify the caller, never the slot number alone.
 lda M_DRAW_FIRE
 bne @fire
 lda N_IsSamus
 bne @mario
 lda N_MainRoutine
 cmp #8
 bne @native
 lda N_PageIndex
 bne @native
@mario:
 jmp DrawMario
@fire:
 jmp DrawFire
@native:
 ldx $5B
 jmp N_DrawSpriteObject
DrawMario:
 jsr Init
 lda #3
 sta M_POSE
 lda $1E
 cmp #8
 beq @front
 lda $0300
 cmp #9
 beq @front
 cmp #$FF
 beq @front
 cmp #7
 bcc @normal
 lda #12
 bne @setPose
@front:
 lda M_THROW
 bne @normal
 lda #13
 bne @setPose
@normal:
 lda $0300
 cmp #3
 beq @bodyMotion
 lda M_THROW
 beq @bodyMotion
 lda #14
 bne @setPose
@bodyMotion:
 lda M_STATE
 beq @walk
 lda #4
 bne @form
@walk:
 lda M_DX
 beq @formIdle
 inc M_TIMER
 lda M_TIMER
 cmp M_ANIM_SET
 bcc @walkFrame
 lda #0
 sta M_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc @walkFrame
 lda #0
 sta M_ANIM
@walkFrame:
 lda M_ANIM
 bne @form
 beq @form
@formIdle:
 lda #3
@form:
 ldx $0300
 cpx #3
 bne @setPose
 clc
 adc #6
@setPose:
 sta M_POSE
 asl
 asl
 asl
 sta M_TILE
 lda $0E
 sec
 sbc #8
 sta M_OAMX
 lda $10
 sec
 sbc #16
 ldx M_POSE
 cpx #6
 bcc :+
 cpx #12
 bcs :+
 ; Ball is 16px tall in the native engine, so its bottom remains aligned.
 sec
 sbc #8
:
 sta M_OAMY
 lda $4D
 beq :+
 lda #$40
:
 ldx M_POSE
 cpx #13
 bne :+
 lda #0
:
 sta M_ATTR
 lda N_ObjectCntrl
 and #3
 ora M_ATTR
 sta M_ATTR
 lda #0
 sta M_INDEX
 ldx $5B
@sprite:
 ldy M_TILE
 lda MarioTiles,y
 sta $0201,x
 lda M_ATTR
 sta $0202,x
 lda M_INDEX
 and #1
 bit M_ATTR
 bvc :+
 eor #1
:
 asl
 asl
 asl
 clc
 adc M_OAMX
 sta $0203,x
 lda M_INDEX
 and #6
 asl
 asl
 clc
 adc M_OAMY
 cmp #$EF
 bcc :+
 lda #$F8
:
 sta $0200,x
 inx
 inx
 inx
 inx
 beq @done
 inc M_TILE
 inc M_INDEX
 lda M_INDEX
 cmp #8
 bne @sprite
@done:
 stx $5B
 jmp N_ClearObjectCntrl
DrawFire:
 ldx N_PageIndex
 lda #4
 sta $0301,x
 sta $0302,x
 lda $0E
 sec
 sbc #4
 sta M_OAMX
 lda $10
 sec
 sbc #4
 sta M_OAMY
 ldx $5B
 lda M_OAMX
 sta $0203,x
 lda M_OAMY
 sta $0200,x
 lda N_FrameCount
 lsr
 lsr
 and #1
 tay
 lda FireTiles,y
 sta $0201,x
 lda #0
 sta $0202,x
 inx
 inx
 inx
 inx
 stx $5B
 jmp N_ClearObjectCntrl
ContactGate:
 bcs @return
 lda M_NATIVE
 bne @native
 lda M_GRACE
 bne @return
 lda M_VY
 bmi @native
 lda $6AF4,x
 cmp #4
 bcs @native
 lda $040F,x
 and #$40
 bne @native
 lda $040B,x
 cmp #$FF
 beq @native
 lda $030C
 cmp $6AFB,x
 bne @native
 lda $0400,x
 sec
 sbc $6AF5,x
 sta M_TMP
 lda M_PREV_Y
 clc
 adc $0301
 sec
 sbc M_TMP
 cmp #5
 bcc @stomp
 cmp #$F0
 bcc @native
@stomp:
 lda #$81
 sta $040E,x
 lda $0404,x
 ora #$20
 sta $0404,x
 jsr Bounce
 rts
@return: rts
@native:
 clc
 jsr N_SetEnemyTouchingSamusFlags
 jmp N_CollisionDetectionEnemy_ReactToCollisionWithSamus+5
Bounce:
 lda #$FC
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta M_Y_FRAC
 lda #$20
 sta M_GRAVITY
 lda #$70
 sta M_FALL_FORCE
 lda #1
 sta M_STATE
 lda #8
 sta M_GRACE
 rts
MellowContactGate:
 bcs @return
 lda M_NATIVE
 bne @native
 lda M_GRACE
 bne @return
 lda M_VY
 bmi @native
 lda $030C
 cmp N_Mellows_0_hi,x
 bne @native
 lda N_Mellows_0_y,x
 sec
 sbc #4
 sta M_TMP
 lda M_PREV_Y
 clc
 adc $0301
 sec
 sbc M_TMP
 cmp #5
 bcc @stomp
 cmp #$F0
 bcc @native
@stomp:
 jsr N_CollisionDetectionMellow_Hit
 jmp Bounce
@return: rts
@native:
 jsr N_IsScrewAttackActive
 jmp N_CollisionDetectionMellow_ReactToCollisionWithSamus+5
FireInit:
 tya
 tax
 inc $0300,x
 lda #6
 sta M_THROW
 lda #0
 sta M_FIRE_INIT,x
 rts
Projectiles:
 jsr N_UpdateSamusProjectiles
 lda $58
 bne @clear
 lda $0300
 cmp #7
 bcs @clear
 lda $12
 and #$40
 beq @updates
 ldy #$C0
 lda $03C0
 beq @spawn
 ldy #$50
 lda $0350
 bne @updates
@spawn:
 jsr N_InitBullet
 ldx N_PageIndex ; restore below after native initializer uses X
 tya
 tax
 lda #0
 sta $030A,x
 sta M_FIRE_INIT,x
 lda #1
 sta $030B,x
 lda #4
 sta $0301,x
 sta $0302,x
 lda $030C
 sta $030C,x
 lda $030D
 sec
 sbc #4
 sta $030D,x
 lda $030E
 sta $030E,x
 lda #4
 ldy $4D
 beq :+
 lda #$FC
:
 sta $0309,x
 lda #100
 sta $030F,x
@updates:
 ldx #$50
 jsr OwnFireUpdate
 ldx #$C0
 jmp OwnFireUpdate
@clear:
 lda #0
 sta $0350
 sta $03C0
 rts
OwnFireUpdate:
 stx N_PageIndex
 lda $0300,x
 beq @done
 cmp #1
 bne @nativeEffect
 dec $030F,x
 beq @expire
 lda $030B,x
 beq @expire
 lda $030A,x
 bne @expire
 lda #1
 sta N_UpdatingSamusProjectile
 jsr FireMove
 bcs @draw
 ldx N_PageIndex
 lda #0
 sta $0300,x
@draw:
 lda #0
 sta N_UpdatingSamusProjectile
 ldx N_PageIndex
 lda $0300,x
 beq @done
 lda #1
 sta M_DRAW_FIRE
 jsr N_AnimDrawObject
 lda #0
 sta M_DRAW_FIRE
 rts
@nativeEffect:
 jmp N_DoOneSamusProjectile
@expire:
 lda #0
 sta $0300,x
@done: rts
EnemyFireCheck:
 jsr N_GetEnemyXSlotPosition
 lda $6AF4,x
 cmp #5
 beq @done
 ldy #$50
 jsr @shot
 ldy #$C0
@shot:
 lda $0300,y
 cmp #1
 bne @done
 lda $030A,y
 bne @done
 jsr N_CollisionDetectionEnemy_CheckWithObjectYSlot
 jmp N_CollisionDetectionEnemy_ReactToCollisionWithSamusProjectile
@done: rts
MellowFireCheck:
 jsr N_GetMellowXSlotPosition
 ldy #$50
 jsr @shot
 ldy #$C0
@shot:
 lda $0300,y
 cmp #1
 bne @done
 jsr N_CollisionDetectionMellow_CheckWithObjectYSlot
 jmp N_CollisionDetectionMellow_ReactToCollisionWithSamusProjectile
@done: rts
FireMove:
 ; Native movement checks block boundaries, so sweep the visible ball one pixel
 ; at a time vertically. A multi-pixel step can skip its only floor probe.
 ldx N_PageIndex
 lda #4
 sta $0301,x
 sta $0302,x
 lda M_FIRE_INIT,x
 bne @moving
 inc M_FIRE_INIT,x
 lda #1
 sta M_FIRE_VY,x
 lda #0
 sta M_FIRE_FRAC,x
 sta M_FIRE_YPOS,x
@moving:
 clc
 lda M_FIRE_FRAC,x
 adc M_FIRE_YPOS,x
 sta M_FIRE_YPOS,x
 lda M_FIRE_VY,x
 adc #0
 sta BASE+49
 bpl :+
 eor #$FF
 clc
 adc #1
:
 sta BASE+47
 lda $0309,x
 sta BASE+48
 lda #0
 sta $0309,x
 lda BASE+49
 beq @horizontal
 bmi @up
 lda #1
 bne @speed
@up:
 lda #$FF
@speed:
 sta $0308,x
@pixel:
 lda BASE+49
 bmi @probeUp
 jsr N_ObjectCheckMoveDown
 bcs @movePixel
 ldx N_PageIndex
 lda #$FD
 sta M_FIRE_VY,x
 lda #0
 sta M_FIRE_FRAC,x
 sta M_FIRE_YPOS,x
 beq @horizontal
@probeUp:
 jsr N_ObjectCheckMoveUp
 bcc @expire
@movePixel:
 jsr N_UpdateBullet_Move
 ldx N_PageIndex
 lda $0300,x
 beq @expire
 dec BASE+47
 bne @pixel
@horizontal:
 ldx N_PageIndex
 lda BASE+48
 sta $0309,x
 lda #0
 sta $0308,x
 lda M_FIRE_FRAC,x
 clc
 adc #$50
 sta M_FIRE_FRAC,x
 lda M_FIRE_VY,x
 adc #0
 cmp #5
 bcc :+
 cmp #$80
 bcs :+
 lda #4
:
 sta M_FIRE_VY,x
 jmp N_UpdateBullet_CollisionWithBG
@expire:
 ldx N_PageIndex
 lda #0
 sta $0300,x
 clc
 rts
.include "art.inc"

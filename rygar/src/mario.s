.setcpu "6502"
.macpack longbranch
.include "state.inc"
.export Boot,Calculate,DrawGate,Palette,Step,Jump,Horizontal,Vertical
.export X_Physics,GetPlayerAnimSpeed,ImposeFriction,MarioTiles,FireTiles
.export BeginStep,Response,StompBounce
.export BeginOverhead,FireUpdate,FireDraw,FB
.export ContactDamage
.export SpawnReset
.export StreamArt,DynamicFrames
.export UpdateCamera
.export FinishFrame,FirePoint
.export M_STATE,M_HELD,M_PREV,M_FACING,M_SMB_X_SPEED,M_SMB_X_FORCE,M_SMB_X_ABS,M_X_FRAC,M_Y_FRAC,M_VY,M_VY_FRAC,M_GRAVITY,M_FALL_FORCE,M_POSE
.segment "BOOT"
Boot:
 sei
 cld
 ldx #$FF
 txs
 lda #0
 sta $2000
 sta $2001
 lda #8
 sta BankEight
 lda #0
 sta $00
 sta $02
 lda #$80
 sta $01
 lda #$60
 sta $03
 ldy #0
@copy:
 lda ($00),y
 sta ($02),y
 iny
 bne @copy
 inc $01
 inc $03
 lda $03
 cmp #$80
 bne @copy
 lda #0
 sta $C000
 jmp $C004
BankEight: .byte 8
.segment "CODE"
Init:
 lda M_MAGIC
 cmp #$4D
 beq @done
 lda #0
 ldx #$7F
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
 lda #$FF
 sta M_WORLD
 sta M_ART_WORLD
 sta M_DYN_SHOWN
 lda #$4D
 sta M_MAGIC
@done:rts
SpawnReset:
 jsr Init
 jsr ResetMotion
 lda #0
 sta M_GRACE
 sta M_ANIM
 sta M_TIMER
 sta M_HELD
 sta M_PREV
 sta FB
 sta FB+16
 sta M_DYN_READY
 sta M_DYN_PHASE
 sta M_DYNAMIC
 sta M_VIEW_FLIP
 lda #2
 sta M_VIEW
 lda #$FF
 sta M_WORLD
 sta M_ART_WORLD
 sta M_DYN_SHOWN
 lda $20
 and #2
 beq :+
 lda #1
 sta M_DYN_READY
 lda #0
 sta M_DYN_SHOWN
 sta M_DYN_BUFFER
 sta M_DYN_WANT
 sta M_VIEW
 lda $1C
 sta M_ART_WORLD
:
 lda #1
 sta M_FACING
 sta M_MOVING_DIR
 lda HOST_SCROLL_X
 sta M_LAST_SCROLL_X
 lda HOST_SCROLL_Y
 sta M_LAST_SCROLL_Y
 lda #0
 sta $18
 rts
BeginStep:
 jsr Init
 lda M_GRACE
 beq :+
 dec M_GRACE
:
 lda $1C
 cmp M_WORLD
 beq :+
 sta M_WORLD
 jsr ResetMotion
 lda #0
 sta FB
 sta FB+16
:
 jsr FireUpdate
 ; Low action groups are normal side-view movement. All equipment,
 ; overhead paths, hurt, death and scripted actions keep native integration.
 lda $04B2
 and #$78
 cmp #$18
 bcc @ordinary
 cmp #$18
 beq @ordinary
 cmp #$28
 beq @ordinary
 cmp #$68
 beq @ordinary
@native:
 lda $04B2
 and #$78
 cmp #$30
 bcc :+
 cmp #$40
 bcs :+
 lda $28
 and #$0C
 beq :+
 jsr AnimateClimb
:
 jsr ResetMotion
 ldx #0
 clc
 jmp $962B
@ordinary:
 lda $0492
 and #$A0
 beq @native
 jsr Step
 ldx #3
@save:
 lda $04,x
 sta M_PRED,x
 dex
 bpl @save
 lda M_STATE
 bne @prediction
 ; Native terrain probes need their normal downward subpixel nudge even
 ; while SMB is grounded. Only the probe receives it, never free motion.
 lda $04E2
 and #$F8
 clc
 adc #$20
 sta $04
 lda $05
 adc #0
 sta $05
 lda #4
 sta $04C2
@prediction:
 ldx #0
 rts
BeginOverhead:
 jsr Init
 jsr ResetMotion
 lda $28
 and #15
 beq :+
 lda #6
 jsr AnimateInterval
:
 jsr FireUpdate
 ldx #0
 clc
 jmp $962B
Calculate:
 lda M_ACTIVE
 beq @native
 lda $04A2
 bne @native
 ldy $FF
 lda $0100,y
 sta M_CONTACT
 ldx #0
 clc
 jsr $962B
 lda M_CONTACT
 and #3
 bne @x
 lda M_STATE
 bne :+
 lda #2
 sta M_STATE
 lda M_FALL_FORCE
 sta M_GRAVITY
:
 lda M_PRED
 sta $04
 lda M_PRED+1
 sta $05
@x:
 lda M_CONTACT
 and #$0C
 bne @done
 lda M_PRED+2
 sta $06
 lda M_PRED+3
 sta $07
@done:
 lda $04
 and #$F8
 sta $04
 lda $04E2
 and #7
 ora $04
 sta $04
 lda $06
 and #$F8
 sta $06
 lda $0502
 and #7
 ora $06
 sta $06
 ldx #0
 rts
@native:
 jsr ResetMotion
 ldx #0
 clc
 jmp $962B
Response:
 lda M_ACTIVE
 beq @native
 lda $09
 and #3
 beq @horizontal
 lda M_VY
 bmi @ceiling
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 jmp @horizontal
@ceiling:
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 lda M_FALL_FORCE
 sta M_GRAVITY
@horizontal:
 lda $09
 and #$0C
 beq @native
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_X_FRAC
@native:
 jmp $A3EB
StompBounce:
 lda M_ACTIVE
 beq @bounce
 lda M_VY
 bpl :+
 lda M_GRACE
 beq @side
:
 lda #$FD
 sta M_VY
 lda #1
 sta M_STATE
 lda #$20
 sta M_GRAVITY
 lda #0
 sta M_VY_FRAC
@bounce:
 lda #6
 sta M_GRACE
 lda #$84
 sta $04C2
 jmp $ADE4
@side:
 jmp $ADF3
ContactDamage:
 lda M_GRACE
 beq :+
 rts
:
 jmp $AE01
ResetMotion:
 lda #0
 sta M_STATE
 sta M_ACTIVE
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_RUNNING_TIMER
 sta M_VY
 sta M_VY_FRAC
 sta M_X_FRAC
 sta M_Y_FRAC
 rts
Step:
 lda #1
 sta M_ACTIVE
 lda M_HELD
 sta M_PREV
 lda $28
 sta M_HELD
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda M_STATE
 beq @input
 lda M_VY
 bmi @input
 lda $0522
 and #$A0
 beq @input
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 jmp @input
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
 jmp @friction
@air:
 lda M_INPUT_DIR
 beq @integrate
@friction:
 jsr ImposeFriction
@integrate:
 jsr Horizontal
 jsr Vertical
 ldx #1
 lda M_SMB_X_SPEED
 beq @direction
 bpl :+
 inx
:
 stx M_MOVING_DIR
@direction:
 lda $04B2
 and #$FE
 ldx M_FACING
 cpx #2
 bne :+
 ora #1
:
 sta $04B2
 ; Native collision only needs a signed velocity direction. Prediction
 ; retains SMB's full precision and terminal-speed fractional behavior.
 lda M_VY
 bmi @up
 cmp #4
 bcc @encode
 lda #$7F
 bne @nativeY
@up:
 cmp #$FC
 bcs @encode
 lda #$80
 bne @nativeY
@encode:
 asl
 asl
 asl
 asl
 asl
@nativeY:
 sta $04C2
 lda M_SMB_X_SPEED
 asl
 sta $04D2
 jsr AnimateMario
 rts
Jump:
 lda M_STATE
 bne @done
 lda M_HELD
 and #$80
 beq @done
 and M_PREV
 bne @done
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
 sta M_VY
 lda #0
 sta M_VY_FRAC
 lda $04F2
 sta M_JUMP_ORIGIN
 lda #1
 sta M_STATE
@done:rts
JumpForce: .byte $20,$20,$1E,$28,$28
FallForce: .byte $70,$70,$60,$90,$90
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB
Horizontal:
 lda M_SMB_X_SPEED
 asl
 asl
 asl
 asl
 clc
 adc M_X_FRAC
 sta M_X_FRAC
 sta $06
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
 plp
 adc $0512
 sta $07
 rts
Vertical:
 lda M_Y_FRAC
 sta $04
 lda $04F2
 sta $05
 lda M_STATE
 beq @done
 lda M_VY
 bpl @fall
 lda M_HELD
 and #$80
 and M_PREV
 bne @position
 lda M_JUMP_ORIGIN
 sec
 sbc $04F2
 cmp #1
 bcc @position
@fall:
 lda M_FALL_FORCE
 sta M_GRAVITY
@position:
 lda M_VY_FRAC
 clc
 adc M_Y_FRAC
 sta M_Y_FRAC
 sta $04
 lda M_VY
 adc $04F2
 sta $05
 lda M_VY_FRAC
 clc
 adc M_GRAVITY
 sta M_VY_FRAC
 lda M_VY
 adc #0
 sta M_VY
 cmp #4
 bmi @done
 lda M_VY_FRAC
 cmp #$80
 bcc @done
 lda #4
 sta M_VY
 lda #0
 sta M_VY_FRAC
@done:rts
DrawGate:
 jsr Init
 lda $0E
 sta M_VRAM_PENDING
 ldx #0
@visible:
 lda $0200,x
 cmp #$EF
 bcc @body
 inx
 inx
 inx
 inx
 cpx #32
 bcc @visible
 jmp @dma
@body:
 lda $0202,x
 and #$20
 sta M_PRIORITY
 lda $1C
 cmp M_ART_WORLD
 beq :+
 sta M_ART_WORLD
 lda #0
 sta M_DYN_PHASE
 sta M_DYN_READY
 lda #$FF
 sta M_DYN_SHOWN
:
 lda #0
 sta M_DYNAMIC
 lda $04F2
 sta M_OAMY
 lda $04A2
 cmp #1
 bne @side
 jsr DirectionalPose
 lda M_DYN_WANT
 jmp @dynamic
@side:
 lda #3
 sta M_POSE
 lda $04B2
 and #$78
 cmp #$18
 bne @air
 lda M_OAMY
 sec
 sbc #7
 sta M_OAMY
 lda #5
 sta M_POSE
 bne @render
@air:
 lda M_ACTIVE
 beq @nativePose
 lda M_STATE
 beq @walk
 lda #4
 sta M_POSE
 bne @render
@nativePose:
 lda $04B2
 and #$78
 cmp #$30
 bcc @walk
 cmp #$40
 bcs @walk
 lda M_ANIM
 and #1
 clc
 adc #20
@dynamic:
 sta M_DYN_WANT
 lda #1
 sta M_DYNAMIC
 lda M_DYN_READY
 bne @render
 lda #3
 sta M_POSE
 jmp @render
@walk:
 lda M_ACTIVE
 beq @nativeWalk
 lda M_FACING
 cmp M_MOVING_DIR
 beq @nativeWalk
 lda M_SMB_X_ABS
 cmp #9
 bcc @nativeWalk
 lda #23
 jmp @dynamic
@nativeWalk:
 lda $04D2
 beq @render
 lda M_ANIM
 sta M_POSE
@render:
 lda #$F8
 sta $0200
 sta $0204
 sta $0208
 sta $020C
 lda $04B2
 and #1
 beq :+
 lda #$40
:
 sta M_ATTR
 lda $04A2
 cmp #1
 bne :+
 lda M_VIEW_FLIP
 sta M_ATTR
:
 lda M_ATTR
 ora M_PRIORITY
 sta M_ATTR
 lda M_POSE
 asl
 asl
 sta M_INDEX
 ldx #0
@cell:
 lda M_OAMY
 cpx #8
 bcc :+
 clc
 adc #16
:
 sta $0210,x
 lda M_DYNAMIC
 beq @staticTile
 lda M_DYN_READY
 beq @staticTile
 txa
 lsr
 clc
 adc M_DYN_BUFFER
 jmp @tile
@staticTile:
 ldy M_INDEX
 lda MarioTiles,y
@tile:
 sta $0211,x
 lda M_ATTR
 sta $0212,x
 txa
 and #4
 beq @first
 lda M_ATTR
 and #$40
 bne @left
 beq @right
@first:
 lda M_ATTR
 and #$40
 bne @right
@left:
 lda $0512
 jmp @x
@right:
 lda $0512
 clc
 adc #8
@x:
 sta $0213,x
 inc M_INDEX
 inx
 inx
 inx
 inx
 cpx #16
 bcc @cell
@dma:
 jsr FireDraw
 rts
FinishFrame:
 ; Prepare the next OAM page after native logic, outside the upload deadline.
 ; The unchanged NMI entry performs its DMA on the following frame.
 jsr $8000
 jmp DrawGate
Palette:
 lda $0C
 and #$7B
 sta $2000
 jsr StreamArt
 lda $2002
 lda #$3F
 sta $2006
 lda #$11
 sta $2006
 lda #$30
 sta $2007
 lda #$27
 sta $2007
 lda #$16
 sta $2007
 lda #$3F
 sta $2006
 lda #0
 sta $2006
 sta $2006
 sta $2006
 lda $2002
 rts
.include "fire.inc"
.include "directional.inc"
.include "camera-delta.inc"
.include "mario-animation.inc"
.include "art.inc"
.include "smb-land.inc"
.segment "ART"
DynamicFrames: .incbin "build/directional-frames.bin"

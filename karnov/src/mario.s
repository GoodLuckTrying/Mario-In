.setcpu "6502"
.macpack longbranch
.include "state.inc"
.export Boot,PlayerGate,DrawGate,Palette,ChrWrite,Step,Horizontal,Vertical,Jump
.export X_Physics,GetPlayerAnimSpeed,ImposeFriction
.export ContactGate,FireCollision,FireUpdate,SpawnFire,FireDraw,FB
.export SpawnReset
.export PlayerSpawnReset
.export PrepareWait
.export UpdateCamera
.export AttackGate
.export CameraStep,ScrollUpload
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
 sta $E000
 lda #$80
 sta $A001
 lda #6
 sta $8000
 lda #16
 sta $8001
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
 lda #6
 sta $8000
 lda #0
 sta $8001
 lda #1
 sta $A000
 jmp $C000
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
 lda #$4D
 sta M_MAGIC
@done:rts
SpawnReset:
 jsr Init
 lda #0
 sta M_ACTIVE
 sta M_STATE
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_SMB_X_ABS
 sta M_RUNNING_TIMER
 sta M_RUNNING_SPEED
 sta M_X_FRAC
 sta M_Y_FRAC
 sta M_VY
 sta M_VY_FRAC
 sta M_GRACE
 sta M_DUCK
 sta M_THROW
 sta M_ANIM
 sta M_TIMER
 sta M_HELD
 sta M_PREV
 sta FB
 sta FB+16
 sta M_ART_READY
 sta M_QUEUE_READY
 lda #$FF
 sta M_PALETTE
 lda #1
 sta M_FACING
 sta M_MOVING_DIR
 lda HOST_SCROLL_X
 sta M_LAST_SCROLL_X
 lda HOST_SCROLL_Y
 sta M_LAST_SCROLL_Y
 ldx #0
 lda #0
 rts
PlayerGate:
 jsr Init
 lda M_THROW
 beq :+
 dec M_THROW
:
 lda $64
 sta M_PREV_Y
 lda M_GRACE
 beq :+
 dec M_GRACE
:
 jsr FireUpdate
 lda $62
 and #$1F
 cmp #9
 bcc @ordinary
 cmp #23
 beq @ordinary
@native:
 lda $62
 and #$1F
 cmp #10
 bcc :+
 cmp #15
 bcs :+
 lda $1B
 and #$30
 beq :+
 jsr AnimateClimb
:
 lda #0
 sta M_ACTIVE
 sta M_STATE
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 lda $62
 and #$1F
 jmp $F29B
@ordinary:
 lda $8B
 cmp #10
 beq @native
 cmp #11
 beq @native
 ; Native climbing, flight, swimming, damage and scripted states own movement.
 lda $1B
 and #$30
 beq @move
 lda $89
 cmp #8
 beq @native
 cmp #9
 beq @native
 lda $8B
 cmp #8
 beq @native
 cmp #9
 beq @native
@move:
 jsr Step
 lda M_STATE
 bne :+
 lda $8B
 cmp #5
 bne :+
 lda $E8
 lsr
 bcs :+
 dec $63
:
 ; Native fire remains available alongside the Mario movement wrapper.
 jsr $FA74
 jsr CameraBoundary
 jmp $FA06
CameraBoundary:
 ; A valid native scroll below the viewport must finish before its bottom
 ; boundary can mean a pit. Keep the feet on screen while terrain arrives.
 lda M_STATE
 beq @done
 lda $C4
 bpl @done
 and #$20
 bne @done
 lda M_VY
 bmi @up
 lda $64
 cmp #172
 bcc @done
 lda #172
 sta $64
@done:rts
@up:
 lda $64
 cmp #72
 bcs @done
 lda #72
 sta $64
 rts
AttackGate:
 lda $21
 and #2
 beq @done
 jsr $FA80
 txa
 pha
 tya
 pha
 jsr SpawnFire
 pla
 tay
 pla
 tax
 lda #$FF
@done:rts
PlayerSpawnReset:
 jsr SpawnReset
 lda #0
 sta $62
 rts
Step:
 lda #1
 sta M_ACTIVE
 lda M_HELD
 sta M_PREV
 lda #0
 sta M_HELD
 lda $1B
 ldx #8
@pad: lsr
 rol M_HELD
 dex
 bne @pad
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda M_STATE
 bne @input
 jsr Floor
 bcs @input
 lda #2
 sta M_STATE
 lda M_FALL_FORCE
 sta M_GRAVITY
@input:
 lda M_STATE
 bne @directions
 lda #0
 sta M_DUCK
 lda M_HELD
 and #4
 beq @directions
 inc M_DUCK
@directions:
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
 beq @pose
 bpl :+
 inx
:
 stx M_MOVING_DIR
@pose:
 jsr AnimateMario
 lda #0
 ldx M_FACING
 cpx #2
 bne :+
 lda #$80
:
 sta $62
 lda M_DUCK
 beq :+
 lda $62
 ora #6
 sta $62
 rts
:
 lda M_STATE
 beq @ground
 lda $62
 ora #8
 ldx M_VY
 bmi :+
 ora #$40
:
 sta $62
 rts
@ground:
 lda M_SMB_X_ABS
 beq @done
 lda $E8
 lsr
 lsr
 lsr
 and #3
 clc
 adc #1
 ora $62
 sta $62
@done:rts
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
 lda $64
 sta M_JUMP_ORIGIN
 lda #1
 sta M_STATE
 lda #6
 jsr $C81D
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
 plp
 adc #0
 sta M_DIR
 bpl :+
 eor #$FF
 clc
 adc #1
:
 sta M_STEPS
 beq @done
@pixel:
 lda $63
 ldx M_DIR
 bmi @left
 clc
 adc #7
 bne @probe
@left:
 sec
 sbc #8
@probe:
 tax
 lda $64
 sec
 sbc #8
 tay
 jsr Point
 jsr WallCode
 bcs @block
 lda M_DUCK
 bne @advance
 ldx $5A
 lda $64
 sec
 sbc #24
 tay
 jsr Point
 jsr WallCode
 bcs @block
@advance:
 ldx M_DIR
 bmi @decrement
 inc $63
 bne @next
@decrement:dec $63
@next:
 dec M_STEPS
 bne @pixel
@done:rts
@block:
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_X_FRAC
 rts
WallCode:
 cmp #1
 beq @yes
 cmp #3
 beq @yes
 cmp #4
 beq @yes
 clc
 rts
@yes:sec
 rts
Point:
 jsr $C3D8
 bpl @direct
 and #$7F
 sta M_TMP
 asl
 clc
 adc M_TMP
 tax
 lda $9BCA,x
 tax
 lda $9AC8,x
 lsr
 lsr
 rts
@direct:
 cmp #16
 bcc @done
 lda #0
@done:
 ora #0
 rts
Floor:
 ldx $63
 ldy $64
 jsr Point
 beq @no
 cmp #12
 beq @no
 cmp #4
 bne @platform
 lda M_STATE
 bne @no
 beq @yes
@platform:
 cmp #2
 bne @yes
 lda M_STATE
 beq @yes
 lda $5B
 and #15
 cmp #4
 bcs @no
@yes:
 sec
 rts
@no:clc
 rts
Vertical:
 lda M_STATE
 bne :+
 rts
:
 lda M_VY
 bpl @fall
 lda M_HELD
 and #$80
 and M_PREV
 bne @position
 lda M_JUMP_ORIGIN
 sec
 sbc $64
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
 lda M_VY
 adc #0
 sta M_DIR
 bpl :+
 eor #$FF
 clc
 adc #1
:
 sta M_STEPS
 beq @gravity
@pixel:
 lda M_DIR
 bmi @up
 jsr Floor
 bcs @land
 inc $64
 jmp @next
@up:
 lda $64
 sec
 sbc #33
 ldx M_DUCK
 beq :+
 clc
 adc #16
:
 tay
 ldx $63
 jsr Point
 jsr WallCode
 bcs @ceiling
 dec $64
@next:
 dec M_STEPS
 bne @pixel
@gravity:
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
@ceiling:
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 rts
@land:
 lda $5B
 and #15
 sta M_TMP
 lda $64
 sec
 sbc M_TMP
 sta $64
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 rts
DrawGate:
 jsr $A070
 jsr Init
 lda #3
 sta M_POSE
 lda M_THROW
 beq :+
 lda $62
 and #$1F
 cmp #9
 bcs :+
 lda M_DUCK
 bne :+
 lda #9
 sta M_POSE
 jmp @palette
:
 lda $62
 and #$1F
 cmp #8
 bne @walk
 lda #4
 sta M_POSE
 bne @palette
@walk:
 cmp #1
 bcc @special
 cmp #5
 bcs @special
 lda M_ANIM
 sta M_POSE
 lda M_FACING
 cmp M_MOVING_DIR
 beq :+
 lda M_SMB_X_ABS
 cmp #9
 bcc :+
 lda #5
 sta M_POSE
:
 jmp @palette
@special:
 cmp #25
 bcc :+
 lda #10
 sta M_POSE
 jmp @palette
:
 cmp #6
 beq @duck
 cmp #7
 bne :+
@duck:
 lda #6
 sta M_POSE
 jmp @palette
:
 cmp #5
 bne :+
 lda #9
 sta M_POSE
:
 cmp #10
 bcc @palette
 cmp #15
 bcs @palette
 lda M_ANIM
 and #1
 clc
 adc #7
 sta M_POSE
@palette:
 lda $62
 and #$80
 lsr
 sta M_ATTR
 ldx $15
 cpx #24
 bne :+
 ldx #4
:
 lda CloneBases,x
 clc
 adc M_POSE
 sta $15
 lda #1
 sta M_ART_READY
 jmp DrawBody
PrepareWait:
 txa
 pha
 tya
 pha
 lda $10
 cmp #7
 bne :+
 jsr DrawLives
 jmp @wait
:
 cmp #8
 bne :+
 jsr DrawEntrance
:
 lda M_ART_READY
 jeq @wait
 lda $10
 cmp #8
 jcc @wait
 cmp #16
 jcs @wait
 ; Two native palettes are commonly identical. Native injury changes only
 ; palette zero; keep its HUD/weapon users on their normal palette one.
 ; Merge only after every native actor has finished drawing this frame.
 lda $68
 and #$40
 bne @aliasStart
 lda $34
 cmp $38
 bne @allocate
 lda $35
 cmp $39
 bne @allocate
 lda $36
 cmp $3A
 bne @allocate
@aliasStart:
 ldx #0
@alias:
 cpx #$14
 bcc @other
 cpx #$2C
 bcc @nextAlias
@other:
 lda $0202,x
 and #3
 bne @nextAlias
 lda $0202,x
 ora #1
 sta $0202,x
@nextAlias:
 inx
 inx
 inx
 inx
 bne @alias
@allocate:
 ; Choose an actually unused palette in the completed final OAM page.
 lda #0
 sta M_USED
 ldx #0
@scan:
 cpx #$14
 bcc @skipBody
 cpx #$2C
 bcc @skip
@skipBody:
 lda $0200,x
 cmp #$EF
 bcs @skip
 lda $0202,x
 and #3
 tay
 lda PaletteBits,y
 ora M_USED
 sta M_USED
@skip:
 inx
 inx
 inx
 inx
 bne @scan
 ldy #0
@pick:
 lda PaletteBits,y
 and M_USED
 beq @chosen
 iny
 cpy #4
 bcc @pick
 ; If all four are live, retain the native palette instead of recoloring enemies.
 lda #$FF
 sta M_PALETTE
 lda #0
 beq @attr
@chosen:
 sty M_PALETTE
 tya
@attr:
 sta M_TMP
 ldx #0
@paint:
 lda $0216,x
 and #$FC
 ora M_TMP
 sta $0216,x
 inx
 inx
 inx
 inx
 cpx #24
 bcc @paint
@wait:
 pla
 tay
 pla
 tax
 jmp $C063
DrawBody:
 ldx #0
@body:
 lda $64
 sec
 sbc #33
 cpx #8
 bcc :+
 clc
 adc #16
:
 sta $0214,x
 txa
 lsr
 clc
 adc #$21
 sta $0215,x
 lda M_ATTR
 sta $0216,x
 txa
 and #4
 beq @first
 lda M_ATTR
 and #$40
 beq @right
@left:
 lda $63
 sec
 sbc #8
 jmp @x
@first:
 lda M_ATTR
 and #$40
 bne @right
 jmp @left
@right:lda $63
@x:sta $0217,x
 inx
 inx
 inx
 inx
 cpx #16
 bcc @body
 lda #$F0
 sta $0224
 sta $0228
 jsr FireDraw
 ; Native damage flashing remains visible; never borrow the invisible native pose.
 lda $68
 and #$40
 beq @done
 lda $E8
 and #2
 beq @done
 lda #$F0
 sta $0214
 sta $0218
 sta $021C
 sta $0220
@done:rts
PaletteBits: .byte 1,2,4,8
CloneBases: .byte 64,75,86,97,108
ChrWrite:
 cpx #2
 bne @native
 lda M_MAGIC
 cmp #$4D
 bne @native
 lda M_ART_READY
 beq @native
 lda $15
 and #$7F
 jmp @write
@native:
 lda $13,x
 and #$3F
@write:
 sta $8001
 rts
Palette:
 lda $10
 cmp #7
 bcc @inactive
 cmp #16
 bcc @active
@inactive:
 lda #0
 sta M_ART_READY
 sta FB
 sta FB+16
 lda #$FF
 sta M_PALETTE
@active:
 lda M_MAGIC
 cmp #$4D
 bne @done
 lda M_PALETTE
 cmp #4
 bcs @done
 asl
 asl
 clc
 adc #$11
 pha
 lda $2002
 lda #$3F
 sta $2006
 pla
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
 jsr $C159
@done:
 lda #0
 sta $5F
 sta $60
 rts
; Two independent SMB fireballs. The host's collected attack remains native.
SpawnFire:
 lda $21
 and #2
 beq @done
 lda #4
 sta M_THROW
 lda FB
 beq @first
 ldx #16
 lda FB+16
 bne @done
 beq @slot
@first:ldx #0
@slot:
 lda #1
 sta FB,x
 lda $63
 sta FB+1,x
 lda $64
 sec
 sbc #20
 sta FB+2,x
 lda #3
 sta FB+3,x
 lda #0
 sta FB+4,x
 sta FB+5,x
 lda $62
 and #$80
 sta FB+6,x
@done:rts
FireUpdate:
 jsr UpdateCamera
 ldx #0
 jsr FireOne
 ldx #16
FireOne:
 lda FB,x
 jeq @done
 inc FB,x
 stx M_FB_INDEX
 lda FB+1,x
 sec
 sbc M_CAM_DELTA_X
 sta FB+1,x
 lda FB+2,x
 sec
 sbc M_CAM_DELTA_Y
 sta FB+2,x
 lda FB+6,x
 bmi @left
 lda FB+1,x
 clc
 adc #4
 jcs @kill
 jmp @x
@left:
 lda FB+1,x
 sec
 sbc #4
 jcc @kill
@x:
 sta FB+1,x
 lda FB+4,x
 clc
 adc FB+5,x
 sta FB+5,x
 lda FB+3,x
 adc FB+2,x
 sta FB+2,x
 cmp #8
 bcc @kill
 cmp #184
 bcs @kill
 lda FB+4,x
 clc
 adc #$50
 sta FB+4,x
 lda FB+3,x
 adc #0
 sta FB+3,x
 bmi @wall
 cmp #4
 bcc @floor
 lda #4
 sta FB+3,x
@floor:
 lda FB+2,x
 clc
 adc #8
 tay
 lda FB+1,x
 clc
 adc #4
 tax
 jsr Point
 beq @restore
 cmp #12
 beq @restore
 cmp #8
 beq @restore
 cmp #9
 beq @restore
 ldx M_FB_INDEX
 lda #$FD
 sta FB+3,x
 lda #0
 sta FB+4,x
 jmp @wall
@restore:
 ldx M_FB_INDEX
@wall:
 lda FB+2,x
 clc
 adc #3
 tay
 lda FB+1,x
 clc
 adc #4
 tax
 jsr Point
 jsr WallCode
 ldx M_FB_INDEX
 bcs @kill
@done:rts
@kill:
 lda #0
 sta FB,x
 rts
FireDraw:
 ldx #0
 ldy #0
 jsr FireCell
 ldx #16
 ldy #4
FireCell:
 lda FB,x
 beq @done
 lda FB+2,x
 sta $0224,y
 lda FB+1,x
 sta $0227,y
 lda $E8
 and #4
 lsr
 clc
 adc #$1D
 sta $0225,y
 lda M_ATTR
 and #3
 sta $0226,y
@done:rts
FireCollision:
 ldx #0
@check:
 lda FB,x
 beq @next
 lda $46
 clc
 adc #4
 sec
 sbc FB+1,x
 cmp #8
 bcs @next
 lda $47
 sec
 sbc FB+2,x
 cmp $45
 bcs @next
 lda #0
 sta FB,x
 ; Remove only this hook's return, then return directly to the native
 ; hit-box caller with the native damage result and flags.
 pla
 pla
 lda $65
 sta M_OLD_WEAPON
 and #$F0
 sta $65
 jsr $CD51
 sta M_RESULT
 php
 lda M_OLD_WEAPON
 sta $65
 lda M_RESULT
 plp
 rts
@next:
 txa
 clc
 adc #16
 tax
 cpx #32
 bcc @check
 ldx $44
 lda $0651,x
 rts
ContactGate:
 lda M_ACTIVE
 jeq @native
 lda M_STATE
 jeq @native
 lda M_VY
 bpl @descending
 lda M_GRACE
 jeq @native
@descending:
 ldx $44
 lda $0650,x
 and #$7F
 cmp #$27
 bcs @native
 tay
 lda $CDAD,y
 cmp #3
 bcs @native
 tya
 asl
 asl
 tay
 lda $0653,x
 clc
 adc #16
 sec
 sbc $CA50,y
 sta M_ENEMY_TOP
 lda M_PREV_Y
 sec
 sbc M_ENEMY_TOP
 cmp #5
 bcc @cross
 cmp #$80
 bcc @native
@cross:
 lda $64
 clc
 adc #2
 sec
 sbc M_ENEMY_TOP
 cmp #12
 bcs @native
 lda $0652,x
 clc
 adc $CA51,y
 sec
 sbc $63
 cmp $CA53,y
 bcs @native
 lda $0651,x
 and #$0F
 cmp #4
 bcc @native
 lda #$1F
 sta $0655,x
 jsr $CD69
 lda #6
 sta M_GRACE
 lda #1
 sta M_STATE
 lda #$FD
 sta M_VY
 lda #$20
 sta M_GRAVITY
 lda #0
 sta M_VY_FRAC
 lda M_ENEMY_TOP
 sta $64
 lda #8
 ora $62
 and #$BF
 sta $62
 rts
@native:
 lda M_GRACE
 beq :+
 rts
:
 lda $62
 and #$1F
 jmp $C96D
.include "presentation.inc"
.include "camera.inc"
.include "camera-delta.inc"
.include "mario-animation.inc"
.include "smb-land.inc"

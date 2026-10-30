.setcpu "6502"
.macpack longbranch
.include "generated.inc"
.export Boot,Init,DmaGate,MoveGate,AnimGate,DamageGate,HurtBox,LifeGate
.export Step,Stomps,Fireballs,Draw,SelectFrame
.export FrameTail
.export MeleeTop,MeleeBottom
.export BossBlocks
.export SyncNativeAnimation,NativeAnimGate
.export NativeActorDrawGate
.export StairSpriteBank
.export MenuGate
.export GripGate,Contacts,HitEnemy,ReleaseGrips
.export BottomSplitGate
K_POWER=$7C00
K_INV=$7C01
K_READY=$7C02
K_PREV=$7C03
K_Y=$7C04
K_VY=$7C05
K_VF=$7C06
K_YF=$7C07
K_AIR=$7C08
K_OLDY=$7C09
K_STEPS=$7C0A
K_SLOT=$7C0B
K_GRACE=$7C0C
K_KILLS=$7C0D
K_FACING=$7C0E
K_POSE=$7C0F
K_FX=$7C20
K_FY=$7C22
K_FL=$7C24
K_FD=$7C26
K_FV=$7C28
K_FVF=$7C2A
K_TMP=$7C30
K_ATTR=$7C31
K_DX=$7C32
K_DY=$7C33
K_IDX=$7C34
K_YBUF=$7C35
K_LASTLIFE=$7C36
K_LASTPLAYER=$7C37
K_ATTACK=$7C38
K_MASK=$7C39
K_LAST_BANK=$7C3A
K_MENU_HELD=$7C3C
K_CROUCH=$7C3D
K_ORIGIN=$7C3E
M_STATE=$7D00
M_SMB_X_SPEED=$7D01
M_SMB_X_FORCE=$7D02
M_SMB_X_ABS=$7D03
M_RUNNING_SPEED=$7D04
M_RUNNING_TIMER=$7D05
M_FACING=$7D06
M_MOVING_DIR=$7D07
M_MAX_LEFT=$7D08
M_MAX_RIGHT=$7D09
M_FRICTION_LO=$7D0A
M_FRICTION_HI=$7D0B
M_ANIM_SET=$7D0C
M_INPUT_DIR=$7D0D
M_COLL_DIR=$7D0E
M_AREA_TYPE=$7D0F
M_ENGINE_MODE=$7D10
M_HELD=$7D11
M_X_FRAC=$7D12
M_GRAVITY=$7D13
M_FALL_FORCE=$7D14

.segment "BOOT"
Boot:
 sei
 cld
 lda #0
 sta $2000
 sta $2001
 ldx #$FF
 txs
@wait: bit $2002
 bpl @wait
@wait2: bit $2002
 bpl @wait2
 lda #63
 sta BANK_CODE
 bit $2002
 lda #0
 sta $2006
 sta $2006
 lda $2007
 ldy #0
 sty $00
 lda #$60
 sta $01
 ldx #32
@copy: lda $2007
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
 sta $0000,x
 sta $0100,x
 sta $0200,x
 sta $0300,x
 sta $0400,x
 sta $0500,x
 sta $0600,x
 sta $0700,x
 sta $7C00,x
 sta $7D00,x
 inx
 bne @clear
 lda #$FF
 sta K_LAST_BANK
 lda #35
 sta BANK0
 lda #$A5
 sta $051E
 lda #$5A
 sta $051F
 jmp $82BC
LifeGate:
 sta $04A6
 pha
 txa
 pha
 ldx $55
 lda K_READY
 beq @new
 lda K_LASTPLAYER
 cmp $55
 bne @new
 lda $5C,x
 cmp K_LASTLIFE
 bne @new
 lda K_POWER
 jmp @keep
@new:
 lda #0
@keep:
 pha
 lda #0
 ldx #$3F
@clear: sta $7C00,x
 dex
 bpl @clear
 ldx #$1F
@clear2: sta $7D00,x
 dex
 bpl @clear2
 lda #$FF
 sta K_LAST_BANK
 lda #135
 sta K_Y
 lda #$70
 sta M_FALL_FORCE
 lda #1
 sta K_READY
 pla
 sta K_POWER
 ldx $55
 stx K_LASTPLAYER
 lda $5C,x
 sta K_LASTLIFE
 pla
 tax
 pla
 rts
MoveGate:
 lda $51
 cmp #2
 bne @native
 lda $04A6
 bmi @native
 jsr Step
 jsr Stomps
 jsr Fireballs
 jsr Contacts
 rts
@native: jmp $A696
Step:
 lda M_FACING
 bne @directionReady
 lda $69
 and #1
 bne :+
 lda #2
:
 sta M_FACING
 sta M_MOVING_DIR
@directionReady:
 lda $0373
 ora $0374
 beq :+
 jsr ReleaseGrips
:
 lda K_INV
 beq :+
 dec K_INV
:
 lda K_GRACE
 beq :+
 dec K_GRACE
:
 lda $6A
 and #$47
 sta M_HELD
 lda $6A
 and #8
 beq :+
 lda M_HELD
 ora #$80
 sta M_HELD
:
 lda M_HELD
 and #3
 sta M_INPUT_DIR
 lda K_AIR
 sta M_STATE
 bne @crouchReady
 lda #0
 sta K_CROUCH
 lda M_HELD
 and #4
 beq @crouchReady
 lda M_INPUT_DIR
 beq @duck
 lda #0
 sta M_INPUT_DIR
 beq @crouchReady
@duck:
 lda K_POWER
 beq @crouchReady
 inc K_CROUCH
@crouchReady:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 jsr JumpInput
 lda #1
 sta M_AREA_TYPE
 lda #3
 sta M_COLL_DIR
 jsr X_Physics
 lda M_STATE
 bne @airInput
 jsr GetPlayerAnimSpeed
 lda M_INPUT_DIR
 beq @friction
 sta M_FACING
 bne @friction
@airInput:
 lda M_INPUT_DIR
 beq @position
@friction:
 jsr ImposeFriction
@position:
 lda M_SMB_X_SPEED
 beq @fraction
 cmp #$80
 ldx #1
 bcc :+
 inx
:
 stx M_MOVING_DIR
@fraction:
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
 sta K_TMP
 plp
 adc #0
 beq @still
 cmp #0
 bmi @left
 ldy #1
 bne @right
@left:
 eor #$FF
 clc
 adc #1
 ldy #2
@right:
 sta K_STEPS
 sty $67
 tya
 eor #3
 tax
 lda #0
 sta $05
 sta $06
 ; Boss distances do not change until the native camera pass. Repeating
 ; this same scan for every pixel wastes the pre-split CPU budget.
 tya
 pha
 txa
 pha
 jsr BossBlocks
 pla
 tax
 pla
 tay
 bcs @blocked
@pixel:
 jsr $A797
 dec K_STEPS
 bne @pixel
@blocked:
 jsr $A6F6
 jmp @vertical
@still:
 lda #0
 sta $67
 jsr $A734
@vertical:
 lda K_Y
 sta K_OLDY
 lda K_AIR
 jeq @ground
 lda K_VY
 bpl @fall
 lda $6A
 and K_PREV
 and #8
 bne @integrate
 lda K_ORIGIN
 sec
 sbc K_Y
 cmp #1
 bcc @integrate
@fall:
 lda M_FALL_FORCE
 sta M_GRAVITY
@integrate:
 lda K_YF
 clc
 adc K_VF
 sta K_YF
 lda K_Y
 adc K_VY
 cmp #135
 bcc @y
 lda K_VY
 bmi @ceiling
 lda #0
 sta K_AIR
 sta K_VY
 sta K_VF
 sta K_YF
 lda #135
@y: sta K_Y
 lda K_AIR
 beq @ground
@gravity:
 lda K_VF
 clc
 adc M_GRAVITY
 sta K_VF
 lda K_VY
 adc #0
 sta K_VY
 bmi @ground
 cmp #4
 bcc @ground
 lda K_VF
 cmp #$80
 bcc @ground
 lda #4
 sta K_VY
 lda #0
 sta K_VF
 beq @ground
@ceiling: lda #60
 sta K_Y
 lda #0
 sta K_VY
 sta K_VF
 jmp @gravity
@ground:
 lda M_FACING
 cmp #2
 lda $69
 and #$FE
 bcs :+
 ora #1
:
 sta $69
 lda K_Y
 sta $B6
 lda $69
 and #$FB
 ldx K_AIR
 beq :+
 ora #4
:
 sta $69
 jsr SyncNativeAnimation
 lda $6A
 sta K_PREV
 rts
JumpInput:
 lda K_AIR
 bne @done
 lda $6A
 and #8
 beq @done
 and K_PREV
 bne @done
 ldy #0
 lda M_SMB_X_ABS
 cmp #9
 bcc @force
 iny
 cmp #16
 bcc @force
 iny
 cmp #25
 bcc @force
 iny
 cmp #28
 bcc @force
 iny
@force:
 lda JumpForce,y
 sta M_GRAVITY
 lda FallForce,y
 sta M_FALL_FORCE
 lda JumpSpeed,y
 sta K_VY
 lda #0
 sta K_VF
 sta K_YF
 lda K_Y
 sta K_ORIGIN
 lda #1
 sta K_AIR
 sta M_STATE
 lda #$10
 sta $FD
@done:
 rts
JumpForce: .byte $20,$20,$1E,$28,$28
FallForce: .byte $70,$70,$60,$90,$90
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB
BossBlocks:
 ; Preserve the native boss barrier before calling the camera/exit step.
 ; Without this check a faster character could walk straight through a boss.
 ldx #5
@boss:
 lda $87,x
 cmp #2
 bcc @next
 cmp #9
 bcs @next
 tay
 dey
 dey
 lda $04EA,x
 lsr
 lda $67
 bcs @left
 cmp #2
 beq @next
 bne @toward
@left:
 cmp #1
 beq @next
@toward:
 lda $04E3,x
 bne @next
 lda $04DC,x
 cmp $9BA7,y
 bcc @blocked
@next:
 dex
 bpl @boss
 clc
 rts
@blocked:
 sec
 rts
AnimGate:
 jsr $A826
 lda $51
 cmp #2
 bne :+
 lda $04A6
 bmi :+
 lda K_Y
 sta $B6
:
 rts
; Mario's variable jump can outlast Thomas's animation. Reasserting the
; airborne bit with an expired phase makes A8EB index unrelated data as a
; VRAM command, or combines hurt+air into an invalid indirect jump at A834.
; Keep the native animation state/phase coherent before and after its tick.
NativeAnimGate:
 lda $50
 beq @native
 lda $51
 cmp #2
 bne @native
 jsr SyncNativeAnimation
 lda $04A6
 jsr $A829
 php
 pha
 jsr SyncNativeAnimation
 pla
 plp
 rts
@native:
 lda $04A6
 jmp $A829
SyncNativeAnimation:
 lda $04A6
 jmi @done
 lda $69
 and #8
 beq @motion
 lda $69
 and #1
 ora #8
 sta $69
 lda #0
 sta $68
 rts
@motion:
 lda $69
 and #$30
 cmp #$30
 bne :+
 lda $69
 and #$DF
 sta $69
:
 lda K_AIR
 beq @ground
 lda $69
 and #$31
 ora #4
 sta $69
 and #$30
 beq @airPose
 lda $68
 cmp #4
 bcc @endAirAttack
 cmp #6
 bcc @done
@endAirAttack:
 lda $69
 and #1
 ora #4
 sta $69
@airPose:
 lda K_VY
 bmi @ascending
 lda #4
 bne @phase
@ascending:
 lda #5
@phase:
 sta $68
 rts
@ground:
 lda $69
 and #$33
 sta $69
 and #$30
 beq @walkPhase
 lda $68
 cmp #4
 bcc @done
 ; Landing ends an airborne attack instead of reusing its phase as a
 ; ground attack. Clear its timer so the next button press is responsive.
 lda $69
 and #3
 sta $69
 lda #0
 sta $21
@walkPhase:
 lda $69
 and #2
 beq :+
 lda #0
 sta $68
 rts
:
 lda $68
 cmp #2
 bcc @done
 lda #1
 sta $68
@done:
 rts
HurtBox:
 lda $94
 sec
 sbc #6
 sta $00,x
 clc
 adc #12
 sta $02,x
 lda $B6
 clc
 adc #47
 sta $03,x
 ldy K_POWER
 beq @small
 lda K_CROUCH
 bne @crouched
 lda K_AIR
 bne @tall
 lda $6A
 and #7
 cmp #4
 bne @tall
@crouched:
 lda $03,x
 sec
 sbc #21
 bne @top
@tall:
 lda $03,x
 sec
 sbc #29
 bne @top
@small: sec
 sbc #13
@top: sta $01,x
 rts
MeleeTop:
 lda K_POWER
 beq @small
 lda BigTop,y
 bne @height
@small: lda SmallTop,y
@height:
 sta K_TMP
 lda $B6
 clc
 adc #47
 sec
 sbc K_TMP
 rts
MeleeBottom:
 lda K_POWER
 beq @small
 lda BigBottom,y
 bne @height
@small: lda SmallBottom,y
@height:
 sta K_TMP
 lda $B6
 clc
 adc #47
 sec
 sbc K_TMP
 rts
SmallTop: .byte 12,7,12,7,12,7
SmallBottom: .byte 3,1,3,1,3,1
BigTop: .byte 25,22,17,17,25,22
BigBottom: .byte 14,12,8,6,14,12
DamageGate:
 cpx #6
 bne @native
 ; Repeated contacts must leave the native death fall running. Resetting
 ; negative HP to zero restarts it and reactivates the removed player actor.
 lda $04A6
 bmi @native
 lda K_INV
 ora K_GRACE
 bne @ignore
 lda K_POWER
 beq @die
 lda #0
 sta K_POWER
 sta $0496
 lda #120
 sta K_INV
 lda #4
 sta $FD
@ignore:
 lda #0
 sta $037A
 rts
@die:
 lda #0
 sta K_FL
 sta K_FL+1
 sta K_ATTACK
 lda #1
 sta $037A
 lda #0
 sta $04A6
@native:
 lda $04A0,x
 jmp $C465
GripGate:
 ; Native grippers use packed actor stacks in $0373-$0376. Mario's
 ; shrink/stomp recovery cannot leave actors frozen in that grab state.
 ; His ordinary contact boxes below own these collisions instead.
 lda $50
 beq @native
 lda $51
 cmp #2
 bne @native
 clc
 rts
@native:
 lda $9F,x
 cmp #1
 jmp $AE05
ReleaseGrips:
 ldx #3
@actor:
 lda $80,x
 and #4
 beq @next
 lda $80,x
 and #$FB
 sta $80,x
 lda #0
 sta $B7,x
@next:
 dex
 bpl @actor
 lda #0
 sta $0373
 sta $0374
 sta $0375
 sta $0376
 sta $0377
 sta $0378
 rts
HitEnemy:
 ; Match the native attack setup, including a valid score/attack index,
 ; outward defeat direction and a fresh fall counter for reused actors.
 lda #4
 sta $0379
 lda #0
 sta $04D5,x
 sta $0486,x
 sta $04A8,x
 lda $8E,x
 cmp $94
 bcs :+
 inc $04A8,x
:
 lda #1
 sta $FC
 lda #8
 sta $037A
 jmp $C462
Stomps:
 lda K_AIR
 bne @falling
 ; The landing tick clears K_AIR before collision. Still sweep the feet
 ; on that tick, so short snakes cannot slip through the floor crossing.
 lda K_OLDY
 cmp #135
 bcs @done
@falling:
 lda K_VY
 bmi @done
 lda #0
 sta K_SLOT
@enemy:
 ldx K_SLOT
 lda $80,x
 beq @next
 lda $04A0,x
 bmi @next
 lda $87,x
 cmp #14
 bcs @next
 cmp #8
 beq @next
 cmp #9
 beq @next
 tay
 lda $9F,x
 cmp #1
 bne @next
 lda $8E,x
 sec
 sbc $94
 clc
 adc #17
 cmp #35
 bcs @next
 lda $B0,x
 clc
 adc $BBC4,y
 sta K_TMP
 lda K_OLDY
 clc
 adc #44
 cmp K_TMP
 bcs @next
 lda K_Y
 clc
 adc #50
 cmp K_TMP
 bcc @next
 jsr HitEnemy
 lda #1
 sta K_AIR
 lda #$FD
 sta K_VY
 lda #0
 sta K_VF
 lda #16
 sta K_GRACE
@next:
 inc K_SLOT
 lda K_SLOT
 cmp #6
 bcc @enemy
@done: rts
Contacts:
 lda K_INV
 ora K_GRACE
 jne @done
 lda $04A6
 jmi @done
 lda $80
 ora $81
 ora $82
 ora $83
 ora $84
 bne @boxes
 lda $A4
 cmp #1
 jne @done
 lda $85
 jeq @done
@boxes:
 ldx #0
 jsr HurtBox
 ldx #5
@enemy:
 lda $80,x
 jeq @next
 lda $04A0,x
 jmi @next
 lda $9F,x
 cmp #1
 jne @next
 lda $87,x
 cmp #14
 jcs @next
 cmp #8
 beq @next
 cmp #9
 beq @next
 tay
 ; Actor-kind dimensions, rather than Thomas's fixed standing height.
 lda $8E,x
 clc
 adc #9
 cmp $00
 bcc @next
 lda $8E,x
 sec
 sbc #9
 cmp $02
 bcs @next
 lda $B0,x
 clc
 adc $BBC4,y
 cmp $03
 bcs @next
 lda $B0,x
 clc
 cpy #10
 bcs @lowBody
 ; Native melee targets can omit a boss's legs. Body contact still
 ; reaches the feet, including the smaller Mario's standing height.
 adc #47
 jmp @bottom
@lowBody:
 clc
 adc $BBD6,y
@bottom:
 cmp $01
 bcc @next
 lda #1
 sta $037A
 ldx #6
 jsr DamageGate
 rts
@next:
 dex
 bpl @enemy
@done:
 rts
Fireballs:
 lda $03B1
 cmp K_KILLS
 beq @shots
 sta K_KILLS
 and #3
 bne @shots
 lda K_POWER
 cmp #2
 bcs @shots
 inc K_POWER
 lda #$20
 sta $FD
@shots:
 lda K_POWER
 cmp #2
 bne @update
 lda $6A
 and #$40
 beq @update
 ldx $55
 txa
 asl
 tax
 lda $15,x
 and #$40
 beq @update
 ldx #0
 lda K_FL
 beq @spawn
 inx
 lda K_FL+1
 bne @update
@spawn:
 lda #48
 sta K_FL,x
 lda $94
 sta K_FX,x
 lda K_Y
 clc
 adc #35
 sta K_FY,x
 lda #0
 sta K_FV,x
 sta K_FVF,x
 lda $69
 and #1
 tay
 lda ShotSpeed,y
 sta K_FD,x
@update:
 ldx #0
@shot:
 stx K_IDX
 lda K_FL,x
 jeq @next
 dec K_FL,x
 lda K_FX,x
 clc
 adc K_FD,x
 clc
 adc $66
 sta K_FX,x
 cmp #8
 bcc @expire
 cmp #248
 bcs @expire
 lda K_FVF,x
 clc
 adc #$60
 sta K_FVF,x
 lda K_FV,x
 adc #0
 sta K_FV,x
 clc
 adc K_FY,x
 sta K_FY,x
 cmp #177
 bcc @collision
 lda #176
 sta K_FY,x
 lda #$FD
 sta K_FV,x
@collision:
 ldy #0
@target:
 sty K_SLOT
 lda $80,y
 beq @other
 and #8
 beq :+
 lda $87,y
 cmp #15
 bne @other
:
 lda $87,y
 cmp #8
 beq @other
 cmp #9
 beq @other
 lda $04A0,y
 bmi @other
 lda $9F,y
 cmp #1
 bne @other
 lda K_FX,x
 sec
 sbc $8E,y
 clc
 adc #13
 cmp #27
 bcs @other
 lda K_FY,x
 sec
 sbc $B0,y
 clc
 adc #5
 cmp #46
 bcs @other
 tya
 tax
 jsr HitEnemy
 ldx K_IDX
@expire:
 lda #0
 sta K_FL,x
 jmp @next
@other:
 iny
 cpy #6
 bcc @target
@next:
 ldx K_IDX
 inx
 cpx #2
 jne @shot
 rts
ShotSpeed: .byte $FC,4
SelectFrame:
 lda #0
 sta K_ATTACK
 lda $50
 beq @regular
 lda $51
 cmp #3
 bne @regular
 lda $5F
 cmp #4
 bcs @ending
 ; The first four floor exits are scripted stairs, not player movement.
 ; Drop frozen attack/jump/blink state and animate Mario's own walking
 ; cells while the original actor continues moving up the staircase.
 lda #0
 sta K_AIR
 sta K_INV
 sta K_GRACE
 sta K_FL
 sta K_FL+1
 lda $B6
 sta K_Y
 lda $49
 lsr
 lsr
 lsr
 and #1
 ldx K_POWER
 bne :+
 clc
 adc #12
:
 tay
 lda StairBanks,y
 tay
 sty K_POSE
 rts
@ending:
 lda #0
 sta K_AIR
 sta K_INV
 sta K_GRACE
 sta K_FL
 sta K_FL+1
 lda $B6
 sta K_Y
 ldy #23
 lda K_POWER
 beq :+
 ldy #24
:
 sty K_POSE
 rts
@regular:
 ldy #23
 lda K_POWER
 beq :+
 ldy #24
:
 lda $04A6
 bpl :+
 lda #0
 sta K_INV
 sta K_GRACE
 sta K_FL
 sta K_FL+1
 ldy #22
 jmp @pose
:
 lda $23
 bne @hurt
 lda $69
 and #8
 beq @normal
@hurt:
 ldy #20
 lda K_POWER
 jeq @pose
 ldy #11
 jmp @pose
@normal:
 lda $69
 and #$30
 beq @motion
 ; Use the same six standing/crouching/air attack indices as C65B.
 ldx #0
 lda $69
 and #2
 beq :+
 ldx #2
:
 lda $69
 and #4
 beq @groundAttack
 ldx #4
 lda $68
 cmp #5
 bcs @windup
 bcc @active
@groundAttack:
 lda $68
 beq @windup
 cmp #3
 bcs @windup
@active:
 lda $69
 and #$10
 beq :+
 inx
:
 lda #1
 sta K_ATTACK
 lda K_POWER
 beq :+
 lda BigAttack,x
 tay
 jmp @pose
:
 lda SmallAttack,x
 tay
 jmp @pose
@windup:
 txa
 lsr
 tax
 lda K_POWER
 beq :+
 lda BigWindup,x
 tay
 jmp @pose
:
 lda SmallWindup,x
 tay
 jmp @pose
@motion:
 lda K_POWER
 beq :+
 lda K_CROUCH
 beq :+
 ldy #10
 bne @pose
:
 lda K_AIR
 beq @walk
 ldy #16
 lda K_POWER
 beq @pose
 ldy #4
 bne @pose
@walk:
 lda K_POWER
 beq :+
 lda $6A
 and #7
 cmp #4
 bne :+
 ldy #10
 bne @pose
:
 lda $67
 beq @pose
 lda $49
 lsr
 lsr
 lsr
 and #3
 cmp #3
 bne :+
 lda #1
:
 ldx K_POWER
 bne :+
 clc
 adc #12
:
 tay
@pose:
 sty K_POSE
 rts
SmallAttack: .byte 26,27,17,18,19,21
BigAttack: .byte 3,5,6,7,8,9
SmallWindup: .byte 28,25,15
BigWindup: .byte 29,30,4
DmaGate:
 lda $52
 ; The full Thomas-area clear has only a few CPU cycles of vblank margin.
 ; It must bypass even the scene/palette-command dispatch below.
 cmp #$1B
 beq @native
 cmp #$15
 bne @transfer
 lda $50
 beq @native
 lda $51
 cmp #3
 bne @native
 ; The stair palette command only recolors Thomas's sprite palette.
 ; Mario owns that palette here; don't let it undo his colors after DMA.
 lda #0
 sta $52
@transfer:
 ; These transfers consume virtually all of vblank. Take this exit before
 ; even checking the current scene or switching back to its native bank.
 lda $52
 beq @mode
 cmp #$25
 bcc @native
@mode:
 lda $50
 beq @scene
 lda $51
 cmp #1
 beq @playing
 cmp #2
 beq @playing
 cmp #3
 bne @scene
 beq @playing
@scene:
 ; Story hearts use hard-coded tile $09, outside the actor pose scripts.
 ; Restore the entire original bank, not Mario's gameplay bank zero.
 lda K_LAST_BANK
 cmp #35
 beq @native
 lda #35
 sta K_LAST_BANK
 sta BANK0
 bne @native
@playing:
@upload:
 ldy K_POSE
 cpy K_LAST_BANK
 beq @palette
 sty K_LAST_BANK
 lda BankLo,y
 sta $00
 lda BankHi,y
 sta $01
 tya
 ldy #0
 sta ($00),y
@palette:
 ; Native transition commands can replace sprite colors. Reapply Mario's
 ; palette on ordinary frames, yielding with the bank upload above when
 ; a large native transfer needs the entire vblank interval.
 jsr Palette
@native:
 lda #2
 sta $4014
 rts
FrameTail:
 lda $50
 beq @hide
 lda $51
 cmp #1
 beq @draw
 cmp #2
 beq @draw
 cmp #3
 bne @hide
@draw:
 jsr SelectFrame
 jsr Draw
 jmp @tail
@hide:
 jsr HideMario
@tail:
 lda $0537
 jmp $8361
MenuGate:
 ; The original menu cycles with Select. Accept fresh D-pad presses as
 ; well; holding a direction must not race through all four game modes.
 lda $14
 and #$0F
 tay
 lda K_MENU_HELD
 eor #$FF
 sty K_MENU_HELD
 and K_MENU_HELD
 beq @native
 and #$0A
 beq @next
 dec $54
 jmp @show
@next:
 inc $54
@show:
 lda $54
 and #3
 sta $54
 jmp $844E
@native:
 lda $36
 beq @timeout
 jmp $8471
@timeout:
 jmp $846A
Draw:
 ; Native removal owns the life/game-over transition. Hide the custom
 ; sprites once it removes Thomas, and never wrap an off-screen row.
 lda $51
 cmp #3
 bne @death
 lda $5F
 cmp #4
 beq @character
@death:
 lda $04A6
 bpl :+
 lda $86
 jeq HideMario
:
 lda $50
 beq @character
 lda $51
 cmp #3
 bne @character
 lda $5F
 cmp #4
 bcs @character
 lda $60
 cmp #4
 jcs HideMario
@character:
 lda $50
 beq @facing
 lda $51
 cmp #3
 bne @facing
 lda $C6
 jmp @flip
@facing:
 lda $69
@flip:
 and #1
 eor #1
 asl
 asl
 asl
 asl
 asl
 asl
 sta K_ATTR
 lda $94
 sec
 sbc #8
 sta K_DX
 lda $B6
 clc
 adc #15
 jcs HideMario
 sta K_DY
 ldx #$18
 ldy #0
@tile:
 lda K_INV
 beq @visible
 and #2
 bne @hide
@visible:
 lda K_DY
 clc
 adc TileY,y
 bcs @hide
 cmp #240
 bcc @puty
@hide: lda #$F8
@puty: sta $0200,x
 lda K_ATTR
 beq :+
 tya
 eor #1
 tay
:
 lda Tiles,y
 sta $0201,x
 lda K_ATTR
 beq :+
 tya
 eor #1
 tay
:
 lda K_ATTR
 sta $0202,x
 lda TileX,y
 clc
 adc K_DX
 sta $0203,x
 inx
 inx
 inx
 inx
 iny
 cpy #8
 bne @tile
 ; Four cells extend the active limb beyond the original 16-pixel body.
 ; Their pixels and position mirror together when Mario faces left.
 ldy K_POSE
 lda ExtraMask,y
 sta K_MASK
 ldx #$40
 ldy #0
@extra:
 lda #$F8
 sta $0200,x
 lda K_ATTACK
 beq @nextExtra
 lda ExtraBits,y
 and K_MASK
 beq @nextExtra
 lda K_INV
 and #2
 bne @nextExtra
 lda K_DY
 clc
 adc ExtraY,y
 bcs @nextExtra
 cmp #240
 bcs @nextExtra
 sta $0200,x
 lda ExtraTiles,y
 sta $0201,x
 lda K_ATTR
 sta $0202,x
 lda K_ATTR
 beq @extraRight
 lda K_DX
 sec
 sbc #8
 bcc @extraHide
 bcs @extraX
@extraRight:
 lda K_DX
 clc
 adc #16
 bcs @extraHide
@extraX:
 sta $0203,x
 jmp @nextExtra
@extraHide:
 lda #$F8
 sta $0200,x
@nextExtra:
 inx
 inx
 inx
 inx
 iny
 cpy #4
 bne @extra
 lda #$F8
 sta $0238
 sta $023C
 lda K_FL
 beq :+
 lda K_FY
 sta $0238
 lda #FIRE_TILE
 sta $0239
 lda #0
 sta $023A
 lda K_FX
 sta $023B
:
 lda K_FL+1
 beq @palette
 lda K_FY+1
 sta $023C
 lda #FIRE_TILE
 sta $023D
 lda #0
 sta $023E
 lda K_FX+1
 sta $023F
@palette:
 rts
HideMario:
 lda #$F8
 ldx #$18
@cell:
 sta $0200,x
 inx
 inx
 inx
 inx
 cpx #$50
 bcc @cell
 rts
NativeActorDrawGate:
 ; Actor 6 is Thomas's sprite body used by stairs and the death sequence.
 ; Keep its native movement and transition logic, but let Draw own Mario.
 cpx #6
 beq @skip
 lda $80,x
 beq @skip
 jmp $B2D5
@skip:
 jmp $B34B
StairSpriteBank:
 ; Thomas's staircase sprites came from the background pattern table.
 ; Mario stays in the gameplay sprite table; the original actor is hidden.
 lda #0
 sta $63
 jmp $8B78
BottomSplitGate:
 jsr $8EBD
 lda $51
 cmp #3
 bne @done
 lda $60
 cmp #3
 bne @done
 ; Reserving Mario's OAM space shortens the original composition/fill
 ; pass. The lower scroll split used that work as a delay; keep it below
 ; the 184-pixel floor while the scripted stair actor is climbing.
 ldx #$12
 jsr $8EBD
@done:
 rts
Palette:
 bit $2002
 lda #$3F
 sta $2006
 lda #$11
 sta $2006
 lda K_POWER
 cmp #2
 beq @flower
 lda #$16
 sta $2007
 lda #$27
 sta $2007
 lda #$18
 sta $2007
 rts
@flower:
 lda #$37
 sta $2007
 lda #$27
 sta $2007
 lda #$16
 sta $2007
 rts
TileY: .byte 0,0,8,8,16,16,24,24
TileX: .byte 0,8,0,8,0,8,0,8
Tiles: .byte 6,7,8,9,$0C,$0D,$0F,$D6
ExtraY: .byte 0,8,16,24
ExtraTiles: .byte $D7,$D8,$E6,$E7
ExtraBits: .byte 1,2,4,8
StairBanks: .byte 31,32,0,0,0,0,0,0,0,0,0,0,33,34
ExtraMask: .incbin "../build/extra-mask.bin"
BankLo: .incbin "../build/banklo.bin"
BankHi: .incbin "../build/bankhi.bin"
.include "../../src/smb-land.inc"

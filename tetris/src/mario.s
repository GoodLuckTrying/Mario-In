.setcpu "6502"
.macpack longbranch
.include "native.inc"
.export Boot,TrackChr0,SessionGate,UpdateGate,DrawGate,DmaGate
.export Step,Contacts,Tile,Body,Init,Die,Destroy,DeathStep
.export BreakCeiling
.include "memory.inc"

.segment "BOOT"
; Reset still runs entirely from native PRG. The added routines are copied
; from two 4K CHR banks before NMI is enabled, into cartridge work RAM.
Boot:
 lda #0
 sta $2000
 sta $2001
 sta $00
 lda #$60
 sta $01
 lda #30
 sta G_BOOT_BANK
@bank:
 lda G_BOOT_BANK
 sta $BFFF
 jsr N_changeCHRBank0+3
 bit $2002
 lda #0
 sta $2006
 sta $2006
 lda $2007
 ldx #16
 ldy #0
@page:
 lda $2007
 sta ($00),y
 iny
 bne @page
 inc $01
 dex
 bne @page
 inc G_BOOT_BANK
 lda G_BOOT_BANK
 cmp #32
 bne @bank
 lda #0
 sta $BFFF
 jsr N_changeCHRBank0+3
 lda #0
 ldx #0
@clear:
 sta $7800,x
 inx
 bne @clear
 ldx #0
 jmp N_initRamContinued
TrackChr0:
 sta G_NATIVE_BANK
 sta G_LOADED_BANK
 sta $BFFF
 jmp N_changeCHRBank0+3

.segment "CODE"
SessionGate:
 pha
 lda #0
 sta M_MAGIC
 sta M_DEAD
 sta A_STATE
 sta V_PENDING
 sta V_ESCAPES
 sta V_CLOCK
 sta V_REV
 sta V_CLEAR
 lda N_player1_levelNumber
 sta V_ROUND_START
 lda #1
 sta V_HUD
 lda #45
 sta V_WARNING
 lda N_gameMode
 cmp #5
 bne :+
 lda #0
 sta V_MODE
:
 pla
 jmp N_memset_page

Init:
 lda #0
 ldx #$7F
@clear:
 sta $7800,x
 dex
 bpl @clear
 lda #100
 sta M_X
 lda #208
 sta M_Y
 lda #1
 sta M_FACING
 sta M_MOVING_DIR
 sta M_AREA_TYPE
 lda #8
 sta M_ENGINE_MODE
 lda #$70
 sta M_FALL_FORCE
 sta M_GRAVITY
 lda #$4D
 sta M_MAGIC
 ; Type B starts with a pile. Spawn on its highest supporting surface.
 jsr Unembed
 rts

UpdateGate:
 lda V_MODE
 cmp #3
 bne :+
 ; Auto-Classic runs only the native piece engine and CPU controls.
 ; Leaving Mario uninitialized also retains the native sprite bank.
 jsr VInputs
 jmp N_branchOnPlayStatePlayer1
:
 lda V_CLEAR
 beq :+
 jmp VClearStep
:
 lda M_MAGIC
 cmp #$4D
 beq :+
 jsr Init
:
 lda M_DEAD
 beq @alive
 lda M_DEAD
 cmp #80
 bcs @native
 jmp DeathStep
@alive:
 lda N_playState
 cmp #10
 bcs @native
 lda V_MODE
 beq @step
 lda V_PENDING
 beq @step
 lda N_playState
 cmp #3
 bcc @advance
 cmp #8
 bcc @native
@advance:
 jsr VAdvance
 jsr N_savePlayer1State
 jsr VClearShow
 jmp @done
@step:
 lda #0
 sta M_STOMP
 sta S_HORIZONTAL
 sta S_CAN_REJECT
 jsr Step
 lda V_MODE
 beq :+
 lda M_DEAD
 bne :+
 lda M_Y
 cmp #41
 bcs :+
 lda M_VY
 bpl :+
 lda M_STATE
 beq :+
 lda #1
 sta V_PENDING
 lda N_playState
 cmp #3
 bcc @advance
 cmp #8
 bcs @advance
 jmp @native
:
 jsr VInputs
 jsr VFair
 jsr Contacts
 lda M_DEAD
 ora M_STOMP
 bne @done
 jsr N_branchOnPlayStatePlayer1
 ; Rotation, horizontal movement and gravity may move a mino into Mario
 ; after his own movement. Resolve it before staging or locking the piece.
 jmp Contacts
@native:
 jmp N_branchOnPlayStatePlayer1
@done:
 rts

Step:
 lda N_heldButtons_player1
 sta M_HELD
 lda M_Y
 sta M_OLDY
 jsr Unembed
 lda M_DEAD
 jne @done
 lda M_STATE
 beq @support
 lda M_VY
 bmi @input
@support:
 lda M_Y
 sta G_PY
 jsr ProbeLine
 beq @fall
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VF
 sta M_YF
 beq @input
@fall:
 lda M_STATE
 bne @input
 lda #2
 sta M_STATE
 lda M_FALL_FORCE
 sta M_GRAVITY
@input:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda M_HELD
 and #3
 sta M_INPUT_DIR
 lda M_STATE
 bne @jumpInput
 lda M_HELD
 and #4
 beq @jumpInput
 lda #0
 sta M_INPUT_DIR
@jumpInput:
 jsr Jump
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
 lda M_INPUT_DIR
 jsr ImposeFriction
@position:
 jsr MoveX
 jsr MoveY
 lda M_STATE
 beq @walk
 lda #4
 bne @pose
@walk:
 lda M_SMB_X_ABS
 beq @idle
 cmp #11
 bcc @animate
 lda M_INPUT_DIR
 beq @animate
 cmp M_MOVING_DIR
 beq @animate
 lda #6
 bne @pose
@animate:
 inc M_ANIM_TIMER
 lda M_ANIM_TIMER
 cmp M_ANIM_SET
 bcc @walking
 lda #0
 sta M_ANIM_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc @walking
 lda #0
 sta M_ANIM
@walking:
 lda M_ANIM
 clc
 adc #1
 bne @pose
@idle:
 lda #0
@pose:
 sta M_POSE
@done:
 lda M_HELD
 sta M_PREV
 rts

Unembed:
 jsr Body
 beq @done
 lda M_Y
 cmp #64
 bcc @top
 beq @top
 ; Body visits its upper probe first. Jump directly above that occupied
 ; row instead of repeating nine tile lookups for every embedded pixel.
 lda G_PY
 and #$F8
 sta M_Y
 jmp Unembed
@top:
 lda V_MODE
 beq @crushed
 lda M_Y
 cmp #48
 bcc @crushed
 lda G_PY
 and #$F8
 sta M_Y
 jmp Unembed
@crushed:
 jmp Die
@done:
 rts

; A=pixel Y, X=pixel X. Locked playfield cells are the only terrain.
Tile:
 cmp #48
 bcc @top
 cmp #208
 bcs @solid
 sec
 sbc #48
 lsr
 lsr
 lsr
 tay
 lda N_multBy10Table,y
 sta G_ROW
 txa
 cmp #96
 bcc @solid
 cmp #176
 bcs @solid
 sec
 sbc #96
 lsr
 lsr
 lsr
 clc
 adc G_ROW
 tay
 lda $0400,y
 cmp #$EF
 bne @solid
 lda #0
 rts
@top:
 lda V_MODE
 beq @solid
 cpx #96
 bcc @solid
 cpx #176
 bcs @solid
 lda #0
 rts
@solid:
 lda #1
 rts
ProbeLine:
 lda #0
 sta G_PROBE_I
@next:
 ldy G_PROBE_I
 lda M_X
 clc
 adc ProbeX,y
 tax
 lda G_PY
 jsr Tile
 bne @done
 inc G_PROBE_I
 lda G_PROBE_I
 cmp #3
 bne @next
 lda #0
@done:
 rts
ProbeX: .byte 2,8,13
ProbeY: .byte 15,8,1
Body:
 lda #0
 sta G_BODY_I
@next:
 ldy G_BODY_I
 lda M_Y
 sec
 sbc ProbeY,y
 sta G_PY
 jsr ProbeLine
 bne @done
 inc G_BODY_I
 lda G_BODY_I
 cmp #3
 bne @next
 lda #0
@done:
 rts

MoveX:
 lda M_SMB_X_SPEED
 beq @done
 bpl :+
 lda #2
 bne @direction
:
 lda #1
@direction:
 sta M_MOVING_DIR
 lda M_SMB_X_SPEED
 asl
 asl
 asl
 asl
 clc
 adc M_XF
 sta M_XF
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
 sta G_DELTA
 plp
 lda G_DELTA
 adc #0
 beq @done
 jsr SetSteps
@step:
 lda M_X
 sta G_OLDX
 clc
 adc G_SIGN
 cmp #96
 bcc @blocked
 cmp #161
 bcs @blocked
 sta M_X
 jsr Body
 bne @rollback
 jsr ActiveBody
 bne @rollback
 dec G_STEPS
 bne @step
@done:
 rts
@rollback:
 lda G_OLDX
 sta M_X
@blocked:
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_XF
 rts
SetSteps:
 ldx #1
 cmp #0
 bpl :+
 ldx #$FF
 eor #$FF
 clc
 adc #1
:
 sta G_STEPS
 stx G_SIGN
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
 lda JumpSpeed,y
 sta M_VY
 lda JumpForce,y
 sta M_GRAVITY
 lda FallForce,y
 sta M_FALL_FORCE
 lda #0
 sta M_VF
 sta M_YF
 lda M_Y
 sta M_ORIGIN
 lda #1
 sta M_STATE
 lda #3
 sta N_soundEffectSlot1Init
@done:
 rts
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB
JumpForce: .byte $20,$20,$1E,$28,$28
FallForce: .byte $70,$70,$60,$90,$90

MoveY:
 lda M_STATE
 jeq @done
 lda M_VY
 bpl @fallForce
 lda M_HELD
 and M_PREV
 and #$80
 bne @integrate
 lda M_ORIGIN
 sec
 sbc M_Y
 cmp #1
 bcc @integrate
@fallForce:
 lda M_FALL_FORCE
 sta M_GRAVITY
@integrate:
 lda M_YF
 clc
 adc M_VF
 sta M_YF
 lda M_VY
 adc #0
 beq @gravity
 jsr SetSteps
@step:
 lda M_Y
 clc
 adc G_SIGN
 sta M_Y
 lda G_SIGN
 bmi @up
 lda M_Y
 jmp @probe
@up:
 lda M_Y
 sec
 sbc #16
@probe:
 sta G_PY
 jsr ProbeLine
 bne @hit
 dec G_STEPS
 bne @step
@gravity:
 lda M_VF
 clc
 adc M_GRAVITY
 sta M_VF
 lda M_VY
 adc #0
 sta M_VY
 bmi @done
 cmp #4
 bcc @done
 lda M_VF
 cmp #$80
 bcc @done
 lda #4
 sta M_VY
 lda #0
 sta M_VF
@done:
 rts
@hit:
 lda G_SIGN
 bmi @headHit
 lda #0
 sta M_VY
 sta M_VF
 sta M_YF
 sta M_STATE
 rts
@headHit:
 lda M_Y
 sec
 sbc G_SIGN
 sta M_Y
 lda #0
 sta M_VY
 sta M_VF
 sta M_YF
@ceiling:
 jsr BreakCeiling
 lda #2
 sta M_STATE
 jmp @gravity

; The upward movement probe left G_PY at the underside we hit. Break
; occupied cells along Mario's head, then bonk and fall as with SMB bricks.
; Screen bounds are permanent, and the active piece is handled separately.
BreakCeiling:
 lda G_PY
 cmp #48
 bcc @done
 cmp #208
 bcs @done
 sec
 sbc #48
 lsr
 lsr
 lsr
 sta G_BREAK_ROW
 tay
 lda N_multBy10Table,y
 sta G_BREAK_BASE
 lda #0
 sta G_BREAK_COUNT
 sta G_BREAK_I
@cell:
 ldy G_BREAK_I
 lda M_X
 clc
 adc ProbeX,y
 sec
 sbc #96
 cmp #80
 bcs @next
 lsr
 lsr
 lsr
 clc
 adc G_BREAK_BASE
 tay
 lda $0400,y
 cmp #$EF
 beq @next
 lda #$EF
 sta $0400,y
 inc G_BREAK_COUNT
@next:
 inc G_BREAK_I
 lda G_BREAK_I
 cmp #3
 bne @cell
 lda G_BREAK_COUNT
 beq @done
 inc V_REV
 ; Coalesce with an existing board transfer instead of overwriting it.
 lda G_BREAK_ROW
 cmp N_vramRow
 bcs :+
 sta N_vramRow
:
 lda G_BREAK_ROW
 cmp N_player1_vramRow
 bcs :+
 sta N_player1_vramRow
:
 lda #3
 sta N_soundEffectSlot1Init
@done:
 rts

Contacts:
 lda M_DEAD
 jne @done
 lda N_playState
 cmp #1
 beq :+
 cmp #2
 jne @done
:
 lda N_currentPiece
 cmp #19
 jcs @done
 asl
 asl
 sta G_INDEX
 asl
 clc
 adc G_INDEX
 sta G_INDEX
 lda #4
 sta G_COUNT
 lda #0
 sta G_CONTACT_HEAD
@mino:
 ldx G_INDEX
 lda N_orientationTable+2,x
 clc
 adc N_tetriminoX
 cmp #10
 bcs @next
 asl
 asl
 asl
 clc
 adc #96
 sta G_BX
 lda N_orientationTable,x
 clc
 adc N_tetriminoY
 cmp #20
 bcs @next
 asl
 asl
 asl
 clc
 adc #48
 sta G_BY
 lda M_X
 clc
 adc #13
 cmp G_BX
 bcc @next
 lda G_BX
 clc
 adc #8
 sta G_EDGE
 lda M_X
 clc
 adc #2
 cmp G_EDGE
 bcs @next
 ; Feet crossing a block's top takes priority over head contact.
 lda M_VY
 bmi @head
 lda M_OLDY
 cmp G_BY
 bcc @feet
 beq @feet
 bcs @head
@feet:
 lda M_Y
 cmp G_BY
 bcc @head
 jmp Destroy
@head:
 lda M_Y
 sec
 sbc #16
 sta G_HEAD
 lda G_BY
 clc
 adc #8
 cmp G_HEAD
 bcc @next
 beq @next
 lda M_Y
 sec
 sbc #12
 cmp G_BY
 bcc @next
 beq @next
 lda #1
 sta G_CONTACT_HEAD
@next:
 lda G_INDEX
 clc
 adc #3
 sta G_INDEX
 dec G_COUNT
 jne @mino
 lda G_CONTACT_HEAD
 beq @side
 lda S_HORIZONTAL
 bne @side
 lda V_MODE
 beq :+
 lda V_WARNING
 bne @done
:
 jmp Die
@side:
 jmp SideResolve
@done:
 rts

Destroy:
 lda #19
 sta N_currentPiece
 lda #8
 sta N_playState
 lda #0
 sta N_fallTimer
 sta N_holdDownPoints
 sta N_autorepeatY
 sta M_VF
 sta M_YF
 lda G_BY
 sta M_Y
 sta M_ORIGIN
 lda #$FC
 sta M_VY
 lda #$20
 sta M_GRAVITY
 lda #$70
 sta M_FALL_FORCE
 lda #1
 sta M_STATE
 sta M_STOMP
 inc M_KILLS
 bne :+
 inc M_KILLS+1
:
 lda #3
 sta N_soundEffectSlot1Init
 rts
Die:
 lda M_DEAD
 bne @done
 lda #1
 sta M_DEAD
 lda #$FC
 sta M_VY
 lda #0
 sta M_VF
 sta M_YF
 lda #5
 sta M_POSE
 lda #2
 sta N_soundEffectSlot0Init
@done:
 rts
DeathStep:
 inc M_DEAD
 lda M_YF
 clc
 adc M_VF
 sta M_YF
 lda M_Y
 adc M_VY
 ldx M_VY
 bmi :+
 cmp #209
 bcc :+
 lda #209
:
 sta M_Y
 lda M_VF
 clc
 adc #$40
 sta M_VF
 lda M_VY
 adc #0
 sta M_VY
 lda M_DEAD
 cmp #80
 bcc @done
 lda #10
 sta N_playState
 lda #$F0
 sta N_curtainRow
 lda #19
 sta N_currentPiece
@done:
 rts

DrawGate:
 lda V_CLEAR
 jne @done
 jsr N_stageSpriteForNextPiece
 lda M_MAGIC
 cmp #$4D
 jne @done
 lda N_playState
 cmp #10
 jcs @done
 lda M_Y
 cmp #64
 bcs :+
 lda V_MODE
 beq @done
 lda M_Y
 cmp #32
 bcc @done
:
 lda M_Y
 cmp #209
 bcs @done
 ldx N_oamStagingLength
 cpx #$F0
 bcs @done
 lda #0
 sta G_COL
 lda M_FACING
 cmp #2
 bne :+
 lda #$40
:
 ora #3
 sta G_ATTR
@cell:
 lda G_COL
 and #2
 asl
 asl
 clc
 adc M_Y
 sec
 sbc #17
 sta $0200,x
 lda G_COL
 sta G_TILE
 lda G_ATTR
 and #$40
 beq :+
 lda G_TILE
 eor #1
 sta G_TILE
:
 lda G_TILE
 clc
 adc #$F0
 sta $0201,x
 lda G_ATTR
 sta $0202,x
 lda G_COL
 and #1
 asl
 asl
 asl
 clc
 adc M_X
 sta $0203,x
 inx
 inx
 inx
 inx
 inc G_COL
 lda G_COL
 cmp #4
 bne @cell
 stx N_oamStagingLength
@done:
 rts

DmaGate:
 lda G_NATIVE_BANK
 sta G_BANK
 lda M_MAGIC
 cmp #$4D
 bne @bank
 lda G_NATIVE_BANK
 cmp #3
 bne @bank
 lda N_gameMode
 cmp #4
 beq @mario
 cmp #5
 bne @bank
@mario:
 lda M_POSE
 clc
 adc #4
 sta G_BANK
@bank:
 lda G_BANK
 cmp G_LOADED_BANK
 beq @dma
 sta G_LOADED_BANK
 sta $BFFF
 jsr N_changeCHRBank0+3
@dma:
 jsr VHud
 lda #0
 sta $2003
 lda #2
 sta $4014
 rts

.include "../../src/smb-land.inc"
.include "versus.s"
.include "collision.s"
.include "clear.s"
.include "hunt.s"

.setcpu "6502"
.macpack longbranch
.include "state.inc"
.include "native.inc"
.export Boot,Init,Collect,DrawGate,NmiArt,NmiPalette,Spawn,PlayerLoop,WeaponHit,ContactGate
.export Step,Horizontal,Vertical,X_Physics,GetPlayerAnimSpeed,ImposeFriction
.export FireUpdate,RenderAll,GhostHit,LadderJump,FireCollision,Stomp,DrawMario
.export FB,M_FB_INDEX,M_CUSTOM_HIT,M_DUCK,M_HELD,M_PREV,M_FACING
.export M_PREV_Y,M_POSE,M_ART_PHASE,M_FIRE_READY,M_WANT,M_RUNNING_TIMER,M_SMB_X_ABS
.export DrawMenu,M_MENU_CMD
.export CapturePalette, AllocatePalette, BeginRender, FinishRender, M_PALETTE, M_OLD_PALETTE, M_NATIVE_PALS
.export BodyTiles,QueueBody,DmaPage,PlatformGround
.export M_MAGIC,M_STATE,M_SMB_X_SPEED,M_SMB_X_FORCE,M_VY,M_VY_FRAC,M_WANT,M_ACTIVE,M_ART_READY,M_ART_POSE,M_FORM,M_LIVE,M_NATIVE,M_GRACE
.segment "BOOT"
Boot:
 sei
 ldx #$FF
 txs
 lda #0
 sta $2000
 sta $2001
 lda #8
 sta $FFFE ; ROM byte $08: conflict-safe selection of the added load bank.
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
 jmp Startup
.segment "STARTUP"
Startup:
 .incbin "build/native-startup.bin"
.segment "ART"
Frames:
 .incbin "build/source-art/mario-frames.chr"
.segment "CODE"
Init:
 lda M_MAGIC
 cmp #$4D
 beq @done
 lda #0
 ldx #$7F
@clear:
 sta BASE,x
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
 lda #24
 sta M_WANT
 lda #$FF
 sta M_ART_POSE
 sta M_HERO_CMD
 sta M_MENU_CMD
 sta M_OLD_PALETTE
 sta M_PALETTE
 lda #$4D
 sta M_MAGIC
@done: rts
Spawn:
 jsr Init
 lda #0
 sta M_LIVE
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_DUCK
 sta M_HELD
 sta M_PREV
 sta M_NATIVE
 sta M_GRACE
 sta M_ART_READY
 sta M_FIRE_READY
 sta M_MENU_CONTEXT
 sta M_ART_PHASE
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta FB
 sta FB+16
 lda M_NMI_COUNT
 sta M_LAST_SIM
 lda #$FF
 sta M_ART_POSE
 ldx #0
 lda $04F0,x
 jmp N_PlayerSpawn+5
Collect:
 txa
 pha
 tya
 pha
 jsr Init
 pla
 tay
 pla
 tax
 cpx #0
 bne :+
 lda #$FF
 sta M_HERO_CMD
 sta M_MENU_CMD
:
 cpx #1
 bne @hero
 lda $04F1
 bpl @native
 lda $04F3
 bmi @native ; A simultaneous live hero owns the body stream.
 lda $0523
 cmp #$1B
 beq @menu
 cmp #$1D
 bne @native
@menu:
 tya
 clc
 adc #$80
 sta M_MENU_CMD
 jmp @native
@hero:
 cpx #3 ; Native renderer swaps player 0 with actor 3 around collection.
 bne @native
 lda $04F0,x
 bpl @native
 tya
 clc
 adc #$80
 sta M_HERO_CMD
 lda $04F0,x
 and #$20
 sta M_FORM
@native:
 lda $04F0,x
 jmp $800A
DrawGate:
 lda $29
 cmp M_MENU_CMD
 bne @hero
 lda $2A
 cmp #4
 beq DrawMenu
@hero:
 lda $29
 cmp M_HERO_CMD
 bne @native
 lda $2A
 cmp #4
 bne @native
 lda $061D
 and #$10
 bne @native ; Retain the native frog curse and its own art.
 jsr ChoosePose
 lda M_ART_READY
 beq @next
 jsr DrawMario
@next:
 ldx #0
 jmp N_RenderNext
@native:
 ldy #2
 lda ($29),y
 jmp $80D4
DrawMenu:
 lda #2
 jsr MenuContext
 lda #0
 sta M_FORM
 lda #23
 sta M_WANT
 cmp M_ART_POSE
 bne @done
 lda M_ART_READY
 beq @done
 jsr DrawMario
@done:
 ldx #0
 jmp N_RenderNext
MenuContext:
 cmp M_MENU_CONTEXT
 beq @done
 sta M_MENU_CONTEXT
 lda #0
 sta M_ART_READY
 sta M_ART_PHASE
 sta M_FIRE_READY
 sta FB
 sta FB+16
 sta M_LIVE
 lda #$FF
 sta M_ART_POSE
@done: rts
ChoosePose:
 ldy #1
 lda ($29),y
 cmp #$1B
 bne @player
 lda #1
 jsr MenuContext
 lda #0
 sta M_FORM
 lda #23 ; The title selector fits the native 16-pixel menu row spacing.
 jmp @set
@player:
 lda #0
 sta M_MENU_CONTEXT
 lda M_LIVE
 beq @script
 lda M_NATIVE
 bne @script
 lda M_POSE
 bne @set
 beq @set
@script:
 ldy #1
 lda ($29),y
 and #$DF
 cmp #$14
 beq @climb
 cmp #$15
 bne @normalScript
@climb:
 and #1
 clc
 adc #8
 ldx M_FORM
 beq @set
 clc
 adc #12
 jmp @set
@normalScript:
 lda #24
 ldx M_FORM
 beq :+
 lda #23
:
 sta M_POSE
 ldy #1
 lda ($29),y
 cmp #$1A
 bne :+
 lda #22
 bne @set
:
 ldy #0
 lda ($29),y
 cmp M_LAST_Y
 beq @horizontal
 lda #4
 ldx M_FORM
 beq @set
 lda #16
 bne @set
@horizontal:
 ldy #3
 lda ($29),y
 cmp M_LAST_X
 beq @idle
 inc M_TIMER
 lda M_TIMER
 lsr
 lsr
 and #3
 cmp #3
 bcc :+
 lda #1
:
 ldx M_FORM
 beq @set
 clc
 adc #12
 bne @set
@idle:
 lda M_POSE
@set:
 sta M_WANT
 ldy #0
 lda ($29),y
 sta M_LAST_Y
 ldy #3
 lda ($29),y
 sta M_LAST_X
 rts
DrawMario:
 lda M_ART_POSE
 sta M_RENDER_POSE
 lda $2b
 sta M_DRAW_START
 lda $2c
 sta M_DRAW_PAGE
 ldy #3
 lda ($29),y
 sec
 sbc #8
 sta M_OAMX
 ldy #0
 lda ($29),y
 sec
 sbc #24
 sta M_OAMY
 lda $04F3
 and #4
 asl
 asl
 asl
 asl
 sta M_ATTR
 ldx M_ACTIVE
 lda BodyTiles,x
 sta M_BODY_TILE
 stx M_RENDER_ACTIVE
 lda #0
 sta M_INDEX
 lda M_ART_POSE
 cmp #12
 bcc @sprite
 cmp #24
 bcs @sprite
 lda #4
 sta M_INDEX
@sprite:
 lda $2C
 cmp #4
 bcs @done
 ldy #1
 lda M_INDEX
 clc
 adc M_BODY_TILE
 sta ($2B),y
 iny
 lda M_ATTR
 sta ($2B),y
 iny
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
 sta ($2B),y
 ldy #0
 lda M_INDEX
 and #6
 asl
 asl
 clc
 adc ($29),y
 bcs @hidden
 sec
 sbc #24
 bcc @hidden
 cmp #$EF
 bcc :+
@hidden:
 lda #$F8
:
 sta ($2B),y
 clc
 lda $2B
 adc #4
 sta $2B
 bcc :+
 inc $2C
:
 inc M_INDEX
 lda M_INDEX
 cmp #8
 bne @sprite
@done:
 lda $2b
 sta M_DRAW_END
 rts
NmiArt:
 lda $5A
 jne @skip
 lda M_MAGIC
 cmp #$4D
 jne @attributes
 lda M_FIRE_READY
 bne @body
 lda #4
 sta $2006
 lda #0
 sta $2006
 ldx #0
@fire:
 lda FireArt,x
 sta $2007
 inx
 cpx #32
 bne @fire
 inc M_FIRE_READY
 jmp @skip
@body:
 ; Both alternating OAM pages must release the retired body buffer before
 ; another upload can reuse it. A completed upload can precede its first draw.
 lda M_ART_READY
 beq :+
 lda M_DISPLAY_ACTIVE
 cmp #$ff
 beq :+
 cmp M_ACTIVE
 jne @attributes
:
 lda M_ART_PHASE
 bne @pending
 lda M_WANT
 cmp M_ART_POSE
 jeq @attributes
 sta M_ART_TARGET
@pending:
 lda $00
 pha
 lda $01
 pha
 lda M_ART_TARGET
 lsr
 clc
 adc #$70
 sta $01
 lda M_ART_TARGET
 and #1
 lsr
 ror
 sta $00
 lda M_ART_PHASE
 beq :+
 lda $00
 clc
 adc #64
 sta $00
 bcc :+
 inc $01
:
 lda M_ACTIVE
 eor #1
 tax
 lda BodyHi,x
 sta $2006
 lda BodyLo,x
 clc
 adc #$00
 ldx M_ART_PHASE
 beq :+
 clc
 adc #64
:
 sta $2006
 ldy #0
 ldx #4
@copy:
 .repeat 16
 lda ($00),y
 sta $2007
 iny
 .endrepeat
 dex
 bne @copy
 pla
 sta $01
 pla
 sta $00
 inc M_ART_PHASE
 lda M_ART_PHASE
 cmp #2
 bcc @skip
 lda #0
 sta M_ART_PHASE
 lda M_ART_TARGET
 cmp M_WANT
 jne @skip
 sta M_ART_POSE
 lda M_ACTIVE
 eor #1
 sta M_ACTIVE
 lda #1
 sta M_ART_READY
@skip:
 lda $5a
 beq @attributes
 jmp $C209
@attributes:
 jmp $C1D3
NmiPalette:
 lda M_MAGIC
 cmp #$4D
 bne @native
 inc M_NMI_COUNT
 lda M_OLD_PALETTE
 cmp #4
 bcs @choose
 asl
 asl
 tax
 clc
 adc #$11
 pha
 lda #$3F
 sta $2006
 pla
 sta $2006
 lda M_NATIVE_PALS+1,x
 sta $2007
 lda M_NATIVE_PALS+2,x
 sta $2007
 lda M_NATIVE_PALS+3,x
 sta $2007
@choose:
 lda M_PALETTE
 sta M_OLD_PALETTE
 cmp #4
 bcs @native
 asl
 asl
 clc
 adc #$11
 pha
 lda #$3f
 sta $2006
 pla
 sta $2006
 lda M_DISPLAY_POSE
 sec
 sbc #12
 cmp #12
 bcc @small
 lda #$30
 sta $2007
 lda #$27
 sta $2007
 lda #$16
 sta $2007
 jmp @native
@small:
 lda #$16
 sta $2007
 lda #$27
 sta $2007
 lda #$18
 sta $2007
@native:
 lda $2002
 rts
PlayerLoop:
 jsr Init
 ldx #0
 lda M_NATIVE
 beq @loop
 lda #0
 sta M_NATIVE
 sta M_STATE
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_RUNNING_TIMER
 sta M_VY
 sta M_VY_FRAC
 sta $05C5
 lda M_NMI_COUNT
 sta M_LAST_SIM
@loop:
 ldx #0
 jsr N_PlayerPalette
 lda $C9
 jne @clear
 lda $061D
 and #$10
 jne @frog
 jsr $E014
 jcs @hurt
 lda M_STATE
 bne @move
 lda $CC
 and #$80
 bne @move
 lda $CC
 and #8
 beq @down
 jsr N_LadderHead
 jcc @upLadder
@down:
 lda $CC
 and #4
 beq @move
 jsr N_LadderFoot
 jcc @downLadder
@move:
 ; The native coroutine usually runs once per three video frames. Advance
 ; SMB motion for the elapsed video frames, bounded to avoid a lag burst.
 lda M_NMI_COUNT
 sec
 sbc M_LAST_SIM
 bne :+
 lda #1
:
 cmp #4
 bcc :+
 lda #3
:
 sta M_SUBSTEPS
 lda M_NMI_COUNT
 sta M_LAST_SIM
@substep:
 jsr Step
 jsr FireUpdate
 dec M_SUBSTEPS
 bne @substep
 ldx #0
 jsr N_Camera
 jsr N_Weapon
 jsr N_PlayerFrame
 jsr N_PlayerPosition
 lda M_VY
 bmi :+
 lda M_STATE
 beq :+
 lda $0509
 cmp #$E0
 jcs @pit
:
 jsr N_EndTick
 jmp @loop
@clear:
 jsr Handoff
 jmp N_PlayerLevelClear
@hurt:
 jsr Handoff
 jmp N_PlayerHurt
@pit:
 jsr Handoff
 jmp N_PlayerPit
@frog:
 jsr Handoff
 jmp N_PlayerLoop+3
@upLadder:
 jsr Handoff
 lda #0
 sta $05F1
 jmp N_LadderUp
@downLadder:
 jsr Handoff
 lda #8
 sta $05F1
 jmp N_LadderDown
Handoff:
 lda #1
 sta M_NATIVE
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_RUNNING_TIMER
 sta M_GRACE
 sta FB
 sta FB+16
 rts
LadderJump:
 lda $061D
 and #$10
 bne @frog
 lda #0
 sta M_NATIVE
 sta M_STATE
 sta M_PREV
 sta M_HELD
 sta M_DUCK
 sta M_VY
 sta M_VY_FRAC
 jmp PlayerLoop
@frog:
 jsr $F311
 jmp $DDFA
Step:
 lda #1
 sta M_LIVE
 lda M_HELD
 sta M_PREV
 lda $CC
 sta M_HELD
 and #$40
 bne :+
 lda #0
 sta $85
:
 lda $04F0
 and #$20
 sta M_FORM
 lda $0509
 sta M_PREV_Y
 lda M_GRACE
 beq :+
 dec M_GRACE
:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda M_STATE
 bne @input
 jsr FloorProbe
 bcs @supported
 lda #2
 sta M_STATE
 lda M_FALL_FORCE
 sta M_GRAVITY
@supported:
 lda M_FORM
 bne @notDuck
 lda M_HELD
 and #7
 cmp #4
 bne @stand
 lda #1
 sta M_DUCK
 bne @input
@stand:
 lda M_DUCK
 beq @input
 lda #$E8
 jsr PointY
 cmp #$C6
 bcs @input
@notDuck:
 lda #0
 sta M_DUCK
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
 ; SMB uses $00/$01 as scratch; this host keeps its scheduler task there.
 lda $00
 pha
 lda $01
 pha
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
 pla
 sta $01
 pla
 sta $00
 jsr Horizontal
 jsr Vertical
 lda M_STATE
 beq @direction
 lda M_VY
 bmi @direction
 jsr FloorProbe
 bcc @direction
 jsr Land
@direction:
 ldx #1
 lda M_SMB_X_SPEED
 beq @facing
 bpl :+
 inx
:
 stx M_MOVING_DIR
@facing:
 lda $04F0
 and #$FB
 ldx M_FACING
 cpx #2
 bne :+
 ora #4
:
 sta $04F0
 lda M_FACING
 asl
 asl
 cmp #8
 bne :+
 lda #12
:
 sta $05F1
 lda $04F0
 and #$FD
 ldx M_DUCK
 beq :+
 ora #2
:
 sta $04F0
 lda $061D
 and #$FB
 ldx M_STATE
 beq :+
 ldx M_VY
 bpl :+
 ora #4
:
 sta $061D
 jsr Pose
 ldx #0
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
 sta $05C5
 lda $0599
 sta M_JUMP_ORIGIN
 lda $056D
 sta BASE+62
 lda #1
 sta M_STATE
@done: rts
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
 adc $05DB
 sta $05DB
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
 jsr SideProbe
 bcs @blocked
 lda M_DIR
 bmi @left
 inc $05AF
 bne @next
 inc $0583
 jmp @next
@left:
 lda $05AF
 bne :+
 lda $0583
 beq @blocked
 dec $0583
:
 dec $05AF
@next:
 dec M_STEPS
 bne @pixel
@done: rts
@blocked:
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta $05DB
 rts
Vertical:
 lda M_STATE
 bne @air
 rts
@air:
 lda M_VY
 bpl @fall
 lda M_HELD
 and #$80
 and M_PREV
 bne @position
 lda $056D
 cmp BASE+62
 bne @fall
 lda M_JUMP_ORIGIN
 sec
 sbc $0599
 cmp #1
 bcc @position
@fall:
 lda M_FALL_FORCE
 sta M_GRAVITY
@position:
 lda M_VY_FRAC
 clc
 adc $05C5
 sta $05C5
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
 jsr FloorProbe
 bcs @land
 inc $0599
 lda $0599
 cmp #$F0
 bcc @next
 lda #0
 sta $0599
 inc $056D
 jmp @next
@up:
 lda $056D
 ora $0599
 jeq @ceiling
 lda #$E7
 ldx M_FORM
 bne @smallHead
 ldx M_DUCK
 beq @head
@smallHead:
 lda #$F7
@head:
 jsr PointY
 cmp #$C6
 bcs @ceiling
 lda $0599
 bne :+
 lda #$F0
 sta $0599
 dec $056D
:
 dec $0599
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
@land:
 jmp Land
@ceiling:
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta $05C5
 lda M_FALL_FORCE
 sta M_GRAVITY
 jmp @gravity
Land:
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta $05C5
 rts
FloorProbe:
 ; Native moving actors carry Mario and set the host's support bit before
 ; this player update. Their surface is not present in the background map.
 lda $04f0
 and #$10
 beq :+
 sec
 rts
:
 ; Use the native floor/bridge semantics, sampling at the visible bottom.
 ldx #0
 lda $0599
 pha
 lda $056D
 pha
 sec
 lda $0599
 sbc #3
 sta $0599
 bcs :+
 lda $0599
 sec
 sbc #$10
 sta $0599
 dec $056D
:
 jsr N_Floor
 php
 pla
 sta BASE+63
 pla
 sta $056D
 pla
 sta $0599
 lda BASE+63
 pha
 plp
 rts
PointY:
 ; Signed byte offset from the native center; preserve native 240px pages.
 sta BASE+64
 lda $0599
 clc
 adc BASE+64
 sta $73
 lda $056D
 sta $77
 lda BASE+64
 bmi @negative
 lda $73
 cmp #$F0
 bcc @x
 clc
 adc #$30
 sta $73
 inc $77
 jmp @x
@negative:
 lda $73
 cmp $0599
 bcc @x
 ldx $77
 bne :+
 lda #0
 sta $73
 lda #$C6
 rts
:
 sec
 sbc #$10
 sta $73
 dec $77
@x:
 lda $05AF
 sta $74
 lda $0583
 sta $78
 ldx #0
 jmp N_BgPoint
SideProbe:
 lda #6
 jsr SidePoint
 cmp #$C6
 bcs @solid
 lda #$F9
 jsr SidePoint
 cmp #$C6
 bcs @solid
 lda M_FORM
 ora M_DUCK
 bne @air
 lda #$EB
 jsr SidePoint
 cmp #$C6
 bcs @solid
@air: clc
 rts
@solid: sec
 rts
SidePoint:
 jsr PointY
 ; PointY returned the center tile; only its coordinate setup is reused.
 lda M_DIR
 bmi @left
 clc
 lda $05AF
 adc #8
 sta $74
 lda $0583
 adc #0
 sta $78
 jmp N_BgPoint
@left:
 sec
 lda $05AF
 sbc #8
 sta $74
 lda $0583
 sbc #0
 bcs :+
 lda #$C6
 rts
:
 sta $78
 jmp N_BgPoint
Pose:
 lda #24
 ldx M_FORM
 beq :+
 lda #23
:
 sta M_POSE
 lda M_STATE
 beq @ground
 lda #4
 ldx M_FORM
 beq @set
 lda #16
 bne @set
@ground:
 lda M_DUCK
 beq @walk
 lda #10
 bne @set
@walk:
 lda M_INPUT_DIR
 beq @walking
 cmp M_MOVING_DIR
 beq @walking
 lda M_SMB_X_ABS
 cmp #$0B
 bcc @walking
 lda #3
 ldx M_FORM
 beq @set
 lda #15
 bne @set
@walking:
 lda $061D
 and #2
 beq :+
 lda M_FORM
 bne :+
 lda #11
 bne @set
:
 lda M_SMB_X_SPEED
 beq @done
 inc M_TIMER
 lda M_TIMER
 cmp M_ANIM_SET
 bcc :+
 lda #0
 sta M_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc :+
 lda #0
 sta M_ANIM
:
 lda M_ANIM
 ldx M_FORM
 beq @set
 clc
 adc #12
@set:
 sta M_POSE
@done: rts
WeaponHit:
 lda #0
 sta M_CUSTOM_HIT
 jsr Ordinary
 bcc @native
 jsr Stomp
 bcs @hit
 jsr FireCollision
 bcc @native
@hit:
 inc $0647,x
 inc M_CUSTOM_HIT
 ldy #0 ; Direction-only source for native defeat callbacks.
 lda #1 ; Distinguish the private hit from a disposable native weapon.
 sec
 rts
@native:
 jsr N_ActorActive
 jmp N_WeaponHit+3
GhostHit:
 lda M_CUSTOM_HIT
 beq @native
 jmp $A56D ; Native ghost defeat, without writing projectile flags to Mario.
@native:
 lda $05F1,y
 jmp $A564
Ordinary:
 lda M_LIVE
 beq @no
 lda M_NATIVE
 bne @no
 lda $04F0,x
 bpl @no
 lda $0631,x
 cmp #$0B
 bcs @no
 cmp #5
 beq @no
 cmp #9
 beq @no
 sec
 rts
@no: clc
 rts
Stomp:
 lda M_STATE
 jeq @no
 lda M_VY
 jmi @no
 lda $05AF
 sec
 sbc $05AF,x
 sta M_TMP
 lda $0583
 sbc $0583,x
 beq @right
 cmp #$FF
 bne @no
 lda M_TMP
 beq @no
 eor #$FF
 clc
 adc #1
 jmp @distance
@right:
 lda M_TMP
@distance:
 sta M_TMP
 lda $26
 clc
 adc #8
 cmp M_TMP
 bcc @no
 lda $0509,x
 sec
 sbc $27
 sta M_TMP
 lda $0509
 clc
 adc #8
 sec
 sbc M_TMP
 cmp #12
 bcs @no
 sta M_HIT_GAP
 lda M_PREV_Y
 clc
 adc #8
 sec
 sbc M_TMP
 bmi @bounce
 cmp #5
 bcs @no
@bounce:
 lda $0599
 sec
 sbc M_HIT_GAP
 sta $0599
 bcs :+
 sec
 sbc #$10
 sta $0599
 dec $056D
:
 lda $0509
 sec
 sbc M_HIT_GAP
 sta $0509
 lda #$FC
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta $05C5
 lda #$70
 sta M_GRAVITY
 lda #8
 sta M_GRACE
 sec
 rts
@no: clc
 rts
ContactGate:
 jsr N_ActorActive
 beq @no
 lda $04F0
 and #$41
 bne @no
 lda M_GRACE
 beq @body
 jsr Ordinary
 bcs @no
@body:
 lda $0509
 sta M_CONTACT_Y
 lda #8
 sta M_RADIUS
 lda M_FORM
 ora M_DUCK
 bne @box
 lda #16
 sta M_RADIUS
 lda $0509
 sec
 sbc #8
 sta $0509
@box:
 lda $26
 clc
 adc #7
 sta $24
 lda #0
 sec
 sbc $24
 sta $22
 lda $27
 clc
 adc M_RADIUS
 sta $25
 lda #0
 sec
 sbc $25
 sta $23
 sty $A9
 ldy #0
 jsr $F63A
 php
 lda M_CONTACT_Y
 sta $0509
 plp
 rts
@no: clc
 rts

FireUpdate:
 lda #0
 sta M_FB_INDEX
@slot:
 ldx M_FB_INDEX
 lda FB,x
 jne @move
 lda M_FORM
 jne @next
 lda M_HELD
 and #$40
 jeq @next
 and M_PREV
 jne @next
 lda M_HELD
 ora #$40
 sta M_PREV ; At most one ball per fresh press.
 lda #60
 sta FB,x
 lda $05AF
 sta FB+1,x
 lda $0583
 sta FB+2,x
 lda $0599
 sta FB+3,x
 lda $056D
 sta FB+4,x
 lda #1
 sta FB+5,x
 sta FB+6,x
 lda M_FACING
 cmp #2
 bne :+
 lda #$FF
 sta FB+5,x
:
 lda #0
 sta FB+7,x
 sta FB+8,x
 lda #12
 ldy M_DUCK
 beq :+
 lda #4
:
 sta M_TMP
 lda FB+3,x
 sec
 sbc M_TMP
 sta FB+3,x
 bcs @move
 lda FB+4,x
 jeq @expire
 lda FB+3,x
 sec
 sbc #$10
 sta FB+3,x
 dec FB+4,x
@move:
 dec FB,x
 jeq @next
 lda #3
 sta M_STEPS
@horizontal:
 lda FB+5,x
 bmi @left
 inc FB+1,x
 bne @side
 inc FB+2,x
 jmp @side
@left:
 lda FB+1,x
 bne :+
 dec FB+2,x
:
 dec FB+1,x
@side:
 jsr FirePoint
 cmp #$C6
 jcs @expire
 dec M_STEPS
 bne @horizontal
 lda FB+7,x
 clc
 adc FB+8,x
 sta FB+8,x
 lda FB+6,x
 adc #0
 sta M_DIR
 bpl :+
 eor #$FF
 clc
 adc #1
:
 sta M_STEPS
 beq @gravity
@vertical:
 lda M_DIR
 bmi @up
 lda #4
 jsr FireOffset
 jsr FireFloor
 bcs @bounce
 inc FB+3,x
 lda FB+3,x
 cmp #$F0
 bcc @pixel
 lda #0
 sta FB+3,x
 inc FB+4,x
 jmp @pixel
@up:
 lda FB+3,x
 ora FB+4,x
 jeq @expire
 lda #$FC
 jsr FireOffset
 cmp #$C6
 bcs @ceiling
 lda FB+3,x
 bne :+
 lda #$F0
 sta FB+3,x
 dec FB+4,x
:
 dec FB+3,x
@pixel:
 dec M_STEPS
 bne @vertical
@gravity:
 lda FB+7,x
 clc
 ; SMB1's fireball gravity: $50/256 per update. $10 produced a
 ; roughly 72-pixel arc instead of a short hop after floor contact.
 adc #$50
 sta FB+7,x
 lda FB+6,x
 adc #0
 sta FB+6,x
 bmi @screen
 cmp #3
 bcc @screen
 lda #3
 sta FB+6,x
 bne @screen
@bounce:
 lda #$FD
 sta FB+6,x
 lda #0
 sta FB+7,x
 sta FB+8,x
 beq @screen
@ceiling:
 lda #1
 sta FB+6,x
@screen:
 lda FB+1,x
 sec
 sbc $64
 sta FB+9,x
 lda FB+2,x
 sbc $65
 bne @expire
 lda FB+9,x
 cmp #4
 bcc @expire
 cmp #$F8
 bcs @expire
 lda FB+3,x
 sec
 sbc $67
 sta FB+10,x
 lda FB+4,x
 sbc $68
 beq @bounds
 cmp #1
 bne @expire
 lda FB+10,x
 sec
 sbc #16
 sta FB+10,x
@bounds:
 lda FB+10,x
 cmp #$E8
 bcc @next
@expire:
 lda #0
 sta FB,x
@next:
 lda M_FB_INDEX
 eor #16
 sta M_FB_INDEX
 jne @slot
 ldx #0
 rts
FirePoint:
 lda #0
FireOffset:
 clc
 adc FB+3,x
 sta $73
 lda FB+4,x
 sta $77
 lda $73
 cmp #$F0
 bcc @coordinates
 ; Offsets are only +/-4; distinguish underflow from overflow.
 lda FB+3,x
 cmp #8
 bcs @below
 lda $77
 bne @borrowPage
 lda #$C6
 rts
@borrowPage:
 dec $77
 lda $73
 sec
 sbc #16
 bne @store
@below:
 inc $77
 lda $73
 clc
 adc #16
@store:
 sta $73
@coordinates:
 lda FB+1,x
 sta $74
 lda FB+2,x
 sta $78
 jsr N_BgPoint
 ldx M_FB_INDEX
 rts
FireFloor:
 cmp #$C6
 bcs @done
 ldy $CF
 bne @air
 cmp #$76
 beq @rightHalf
 cmp #$77
 bne @air
 lda $74
 and #15
 cmp #8
 bcc @solid
@air: clc
 rts
@rightHalf:
 lda $74
 and #15
 cmp #8
 rts
@solid: sec
@done: rts
FireCollision:
 stx M_ENEMY
 ldy #0
@slot:
 lda FB,y
 jeq @next
 lda FB+1,y
 sec
 sbc $05AF,x
 sta M_TMP
 lda FB+2,y
 sbc $0583,x
 beq @positiveX
 cmp #$FF
 jne @next
 lda M_TMP
 jeq @next
 eor #$FF
 clc
 adc #1
 jmp @xDistance
@positiveX:
 lda M_TMP
@xDistance:
 sta M_TMP
 lda $26
 clc
 adc #4
 cmp M_TMP
 jcc @next
 lda FB+4,y
 cmp $056D,x
 beq @sameY
 sec
 sbc $056D,x
 cmp #1
 beq @belowY
 cmp #$FF
 jne @next
 lda #$F0
 sec
 sbc FB+3,y
 clc
 adc $0599,x
 jcs @next
 bcc @yDistance
@belowY:
 lda #$F0
 sec
 sbc $0599,x
 clc
 adc FB+3,y
 jcs @next
 bcc @yDistance
@sameY:
 lda FB+3,y
 sec
 sbc $0599,x
 bcs @yDistance
 eor #$FF
 clc
 adc #1
@yDistance:
 sta M_TMP
 lda $27
 clc
 adc #4
 cmp M_TMP
 jcc @next
 lda #0
 sta FB,y
 sec
 rts
@next:
 tya
 eor #16
 tay
 jne @slot
 clc
 rts
RenderAll:
 lda #$ff
 sta M_DRAW_PAGE
 jsr N_RenderMeta
 jsr AllocatePalette
 lda M_FIRE_READY
 beq @done
 ldx #0
@slot:
 lda FB,x
 beq @next
 lda $2C
 cmp #3
 bcs @done ; Keep native first OAM page and its reversal bounded.
 ldy #0
 lda FB+10,x
 sec
 sbc #4
 sta ($2B),y
 iny
 lda FB,x
 and #1
 clc
 adc #$40
 sta ($2B),y
 iny
 lda M_NEXT_PALETTE
 cmp #4
 bcc :+
 lda #0
:
 and #3
 sta ($2B),y
 iny
 lda FB+9,x
 sec
 sbc #4
 sta ($2B),y
 clc
 lda $2B
 adc #4
 sta $2B
 bcc @next
 inc $2C
@next:
 txa
 eor #16
 tax
 bne @slot
@done: rts
FireArt:
 .incbin "build/fire.chr"
; Only retired Arthur body tiles. Font $00-$0f/$1d, armor $20/$21,
; princess $13-$15 and frog $30-$35 remain native.
BodyTiles: .byte $22,$38
BodyHi: .byte $02,$03
BodyLo: .byte $20,$80

.include "smb-land.inc"

.segment "EXTRA2"
; Native palette queue construction runs outside vblank. Keep an untouched
; shadow of the sprite colors so an old Mario palette is always restored.
CapturePalette:
 sta $0720,y
 sta M_PAL_BYTE
 txa
 pha
 lda $25
 cmp #$3f
 bne @done
 lda $23
 sec
 sbc $4a
 clc
 adc $24
 and #$1f
 cmp #$10
 bcc @done
 tax
 lda M_PAL_BYTE
 sta M_NATIVE_PALS-$10,x
@done:
 pla
 tax
 lda M_PAL_BYTE
 rts
BeginRender:
 ; The original renderer builds both DMA pages in place. Preserve its last
 ; complete forward list in the boot-only startup RAM while constructing the
 ; replacement, so NMI never displays partly painted colors or sprite rows.
 ldx #0
@cache:
 lda $0200,x
 sta $7f00,x
 inx
 bne @cache
 lda #1
 sta M_RENDER_BUSY
 ; Keep the displayed palette until the replacement OAM lists are complete.
 lda #$ff
 sta M_RENDER_ACTIVE
 lda #0
 sta M_RENDER_PENDING
 jmp $8089
FinishRender:
 lda M_RENDER_PENDING
 beq @native
 lda M_NEXT_PALETTE
 sta M_PALETTE
 lda M_RENDER_ACTIVE
 sta M_DISPLAY_ACTIVE
 lda M_RENDER_POSE
 sta M_DISPLAY_POSE
 lda #0
 sta M_RENDER_PENDING
 sta M_RENDER_BUSY
@native:
 lda $04f0
 jmp $808c

.segment "EXTRA"
AllocatePalette:
 lda #0
 sta M_USED_PALETTES
 ldx #0
@scan:
 lda $0200,x
 cmp #$ef
 bcs @second
 lda $0201,x
 cmp #$22
 bcc :+
 cmp #$2a
 bcc @second
 cmp #$38
 bcc :+
 cmp #$42
 bcc @second
:
 lda $0202,x
 and #3
 tay
 lda PaletteBits,y
 ora M_USED_PALETTES
 sta M_USED_PALETTES
@second:
 ; Native DMA alternates the forward and reversed OAM pages. Reserve colors
 ; used by either page, including the previous frame during OAM construction.
 lda $0300,x
 cmp #$ef
 bcs @next
 lda $0301,x
 cmp #$22
 bcc :+
 cmp #$2a
 bcc @next
 cmp #$38
 bcc :+
 cmp #$42
 bcc @next
:
 lda $0302,x
 and #3
 tay
 lda PaletteBits,y
 ora M_USED_PALETTES
 sta M_USED_PALETTES
@next:
 txa
 clc
 adc #4
 tax
 bne @scan
@choose:
 ldy #0
@try:
 lda PaletteBits,y
 and M_USED_PALETTES
 beq @found
 iny
 cpy #4
 bne @try
 ldy #$ff
@found:
 sty M_NEXT_PALETTE
 lda #1
 sta M_RENDER_PENDING
 tya
 and #3
 cpy #4
 bcc :+
 lda #0
:
 sta M_USED_PALETTES
 lda M_DRAW_PAGE
 cmp #2
 bne @done
 ldx M_DRAW_START
@paint:
 lda $0202,x
 and #$fc
 ora M_USED_PALETTES
 sta $0202,x
 inx
 inx
 inx
 inx
 beq @done
 cpx M_DRAW_END
 bne @paint
@done:rts
PaletteBits: .byte 1,2,4,8

; Called after native OAM priority selection, before any VRAM work.
DmaPage:
 lda M_RENDER_BUSY
 beq @native
 lda #$7f
 bne @dma
@native:
 lda $b1
@dma:
 sta $4014
 rts

.segment "PLATFORM"
; Native armor-loss streaming still owns armor/frog tiles, but must leave the
; retired Arthur body tiles now used by Mario intact. Consume those source
; chunks without queuing a destructive CHR transfer.
QueueBody:
 lda $25
 cmp #2
 bne @native
 lda $24
 cmp #$20
 bcc @native
 cmp #$a0
 bcs @native
 clc
 adc #$20
 sta $24
 clc
 lda $26
 adc #$20
 sta $26
 bcc :+
 inc $27
:
 lda #0
 rts
@native:
 jmp $eecf

PlatformGround:
 lda M_NATIVE
 bne @native
 jsr Land
 jsr Pose
@native:
 jmp N_PlayerPosition

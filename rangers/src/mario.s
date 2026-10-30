.setcpu "6502"
.macpack longbranch
.include "state.inc"
.import __CODE_LOAD__,__FAST_LOAD__,__FRAMES_LOAD__
.export Boot,MoveGate,DrawGate,DmaGate,ClearGate,DeathGate,SpriteGate,ContactGate
.export Move,LoadState,SaveState,Tile,Compose,Damage,Collect,Stomp,Fireballs
.export X_Physics,ImposeFriction,GetPlayerAnimSpeed,Jump
.export CollisionGate
.export ActorGate,ObjectHitGate
.export ResetGate
.export CollectibleGate
.export PickupObjectGate
.export PaletteUpload,Actions,Palettes,Render,Support,MoveX,MoveY,DrawItems,DrawFire
G_PLAYER=$6980
G_OFFSET=$6981
G_READY=$6982
G_X=$6983
G_XH=$6984
G_Y=$6985
G_YH=$6986
G_TMP=$6987
G_TMP2=$6988
G_SLOT=$6989
G_OAM=$698A
G_FLIP=$698B
G_INDEX=$698C
G_ANCHOR_X=$698D
G_ANCHOR_Y=$698E
G_POSE=$698F
G_KIND=$6990
G_ATTR=$6991
G_FIRE_LIFE=$69A0
G_FIRE_X=$69A4
G_FIRE_XH=$69A8
G_FIRE_Y=$69AC
G_FIRE_YH=$69B0
G_FIRE_VY=$69B4
G_FIRE_FRAC=$69B8
G_FIRE_DIR=$69BC
G_FIRE_OWNER=$69C0
G_ITEM_ACTIVE=$69C4
G_ITEM_X=$69C6
G_ITEM_XH=$69C8
G_ITEM_Y=$69CA
G_ITEM_YH=$69CC
G_ITEM_KIND=$69CE
G_PROXY=$69D0
G_NATIVE_HIT=$69D4
G_COLLECT_PENDING=$69D5
M_ACTION_CARRY=$694B
G_PALETTE=$6300
G_PAL_USE=$69E0
G_PAL_MAP=$69E4
G_PLAYER_PAL=$69E8
G_NATIVE_LIMIT=$69EA

.segment "BOOT"
Boot:
 lda #8
 jsr $FF53
 lda #<__CODE_LOAD__
 sta $00
 lda #>__CODE_LOAD__
 sta $01
 lda #0
 sta $02
 lda #$6A
 sta $03
 ldx #$16
 ldy #0
@copy:
 lda ($00),y
 sta ($02),y
 iny
 bne @copy
 inc $01
 inc $03
 dex
 bne @copy
 ; Private cartridge RAM below the palette/OAM pages holds the unrolled
 ; state loader; frame data uses two otherwise unused pages above OAM.
 ldx #0
@fast:
 lda __FAST_LOAD__,x
 sta $6000,x
 lda __FAST_LOAD__+$100,x
 sta $6100,x
 lda __FAST_LOAD__+$200,x
 sta $6200,x
 lda __FRAMES_LOAD__,x
 sta $6500,x
 lda __FRAMES_LOAD__+$100,x
 sta $6600,x
 inx
 bne @fast
 lda #0
 ldx #0
@clear:
 sta $6800,x
 sta $6900,x
 sta $6400,x
 inx
 bne @clear
 lda #$FF
 ldx #3
@proxies:
 sta G_PROXY,x
 dex
 bpl @proxies
 lda #6
 jsr $FF53
 jmp $C21E

.segment "FAST"
LoadState:
 stx G_PLAYER
 txa
 lsr
 ror
 sta G_OFFSET
 tax
 .repeat $50,I
 lda $6800+I,x
 sta $6900+I
 .endrepeat
 ldx G_PLAYER
 lda M_MAGIC
 cmp #$4D
 beq @done
 lda #0
 ldy #$7F
@clear: sta $6900,y
 dey
 bpl @clear
 lda #$4D
 sta M_MAGIC
 lda #1
 sta M_FACING
 sta M_MOVING_DIR
 sta M_AREA_TYPE
 lda #8
 sta M_ENGINE_MODE
 lda #$70
 sta M_FALL_FORCE
 lda #$FF
 sta M_LAST_WORLD
@done: rts
.segment "CODE"
SaveState:
 ldx G_OFFSET
 .repeat $50,I
 lda $6900+I
 sta $6800+I,x
 .endrepeat
 ldx G_PLAYER
 rts
MoveGate:
 lda $54,x
 cmp #6
 bcc @custom
 cmp #10
 bcc @native
 lda G_OFFSET
 pha
 txa
 pha
 jsr LoadState
 lda #0
 sta M_MAGIC
 jsr SaveState
 pla
 tax
 pla
 sta G_OFFSET
@native:
 ldy $56,x
 beq :+
 jmp $C8F2
:
 jmp $C903
@custom:
 jsr LoadState
 jsr Move
 jmp SaveState
Move:
 ldx G_PLAYER
 lda $56,x
 sta M_ACTION_CARRY
 lda #0
 sta M_STOMP_CHAIN
 lda $31
 cmp M_LAST_WORLD
 beq @same
 sta M_LAST_WORLD
 lda #0
 sta M_SMB_X_SPEED
 sta M_X_FRAC
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 sta M_STATE
 sta M_SUPPLIES
@same:
 lda $16,x
 sta M_HELD
 lda $0510,x
 sta M_PREV_Y
 lda $0520,x
 sta M_PREV_PAGE
 lda M_STOMP_GRACE
 beq :+
 dec M_STOMP_GRACE
:
 lda M_DROP
 beq :+
 dec M_DROP
:
 lda M_THROW
 beq :+
 dec M_THROW
:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda M_POWER_FREEZE
 beq @physics
 dec M_POWER_FREEZE
 jmp @sync
@physics:
 jsr Body
 jsr Support
 lda M_HELD
 and #3
 sta M_INPUT_DIR
 lda M_STATE
 bne @jump
 lda #0
 sta M_CROUCH
 lda M_HELD
 and #4
 beq @jump
 lda M_INPUT_DIR
 beq @duck
 lda #0
 sta M_INPUT_DIR
 beq @jump
@duck:
 lda M_POWER
 beq @jump
 inc M_CROUCH
 lda #0
 sta M_INPUT_DIR
@jump:
 jsr Body
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
 beq @position
@friction:
 jsr ImposeFriction
@position:
 ldx G_PLAYER
 lda M_INPUT_DIR
 sta $52,x
 jsr MoveX
 jsr MoveY
 jsr Actions
@sync:
 ldx G_PLAYER
 lda $54,x
 cmp #6
 bcs @finished
 lda M_STATE
 sta $54,x
 lda M_FACING
 cmp #2
 lda #$D0
 bcc :+
 lda #$90
:
 sta $0400,x
 lda $0340,x
 sta $0420,x
 lda M_HELD
 and #4
 beq :+
 ldy $56,x
 beq :+
 lda $03A0,y
 cmp #$24
 bcs :+
 lda #0
 sta $0420,x
:
 lda M_VY
 eor #$FF
 sta $0560,x
 lda M_VY_FRAC
 eor #$FF
 clc
 adc #1
 sta $0550,x
 bcc :+
 inc $0560,x
:
 lda #$CC
 sta $0530,x
 lda #1
 sta $0540,x
 jsr $D3E7
 jsr $D40B
 jsr CarryHeight
 ; Preserve native collectible/exit tiles at the feet.
 ldx G_PLAYER
 lda #6
 ldy #2
 jsr $F217
 lda $10
 cmp #4
 bne :+
 jsr Damage
:
@collect:
 ldx G_PLAYER
 lda G_COLLECT_PENDING,x
 beq @finished
 dec G_COLLECT_PENDING,x
 jsr Collect
 jmp @collect
@finished:
 lda M_HELD
 sta M_PREV
 ldx G_PLAYER
 rts
Body:
 lda #0
 ldx M_POWER
 beq :+
 ldx M_CROUCH
 bne :+
 lda #1
:
 sta M_TALL
 rts

; A = signed offset from the anchor Y; Y = signed offset from anchor X.
Point:
 sta G_TMP
 sty G_TMP2
 ldx G_PLAYER
 lda $04F0,x
 clc
 adc G_TMP2
 sta G_X
 lda #0
 ldy G_TMP2
 bpl :+
 lda #$FF
:
 adc $0500,x
 sta G_XH
 lda $0510,x
 sta G_Y
 lda $0520,x
 sta G_YH
 lda G_TMP
 bmi @negative
 clc
 adc G_Y
 cmp #$F0
 bcc @y
 adc #$0F
 inc G_YH
 bne @y
@negative:
 clc
 adc G_Y
 bcs @y
 sbc #$0F
 dec G_YH
@y:
 sta G_Y
 jmp Tile
Tile:
 ; Native cache: two horizontal pages, 32-pixel cells, four 4-bit tiles.
 ; The cache wraps vertically. Offscreen points must not read the bottom
 ; row when Mario's head crosses the top of the viewport.
 lda G_Y
 sec
 sbc $FA
 lda G_YH
 sbc $FB
 bne @empty
 lda G_XH
 bmi @empty
 and #1
 asl
 asl
 asl
 asl
 asl
 asl
 asl
 sta G_TMP
 lda G_Y
 and #$E0
 lsr
 ora G_TMP
 sta G_TMP
 lda G_X
 lsr
 lsr
 lsr
 lsr
 and #$0F
 ora G_TMP
 tay
 lda $0600,y
 sta G_TMP
 lda G_Y
 and #$10
 beq :+
 lda G_TMP
 lsr
 lsr
 lsr
 lsr
 rts
:
 lda G_TMP
 and #$0F
 rts
@empty: lda #0
 rts
Feet:
 lda #12
 ldy #$FA
 jsr Point
 jsr IsFloor
 bcs @done
 lda #12
 ldy #5
 jsr Point
 jsr IsFloor
@done: rts
IsFloor:
 cmp #2
 bcc @no
 cmp #6
 beq @no
 cmp #2
 bne @yes
 lda M_DROP
 bne @no
@yes: sec
 rts
@no: clc
 rts
Support:
 lda M_STATE
 bne @done
 jsr Feet
 bcs @done
 ldx G_PLAYER
 lda #$FF
 sta $0560,x
 jsr $F62D
 bcs @done
 lda #2
 sta M_STATE
 lda #0
 sta M_VY
 sta M_VY_FRAC
@done: rts
Jump:
 lda M_HELD
 and #$80
 jeq @done
 lda M_PREV
 and #$80
 bne @done
 lda M_STATE
 bne @done
 lda M_HELD
 and #4
 beq @jump
 lda #12
 ldy #0
 jsr Point
 cmp #2
 bne @jump
 lda #20
 sta M_DROP
 lda #2
 sta M_STATE
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta M_Y_FRAC
 rts
@jump:
 ldy #0
 lda M_SMB_X_ABS
 cmp #9
 bcc @speed
 iny
 cmp #$10
 bcc @speed
 iny
 cmp #$19
 bcc @speed
 iny
 cmp #$1C
 bcc @speed
 iny
@speed:
 lda JumpForce,y
 sta M_GRAVITY
 lda FallForce,y
 sta M_FALL_FORCE
 lda JumpSpeed,y
 sta M_VY
 lda JumpSub,y
 sta M_VY_FRAC
 lda #0
 sta M_Y_FRAC
 lda #1
 sta M_STATE
 ldx G_PLAYER
 lda $0510,x
 sta M_JUMP_ORIGIN
 lda $0520,x
 sta M_Y_PAGE
 lda #$10
 jmp $F379
@done: rts
JumpForce: .byte $20,$20,$1E,$28,$28
FallForce: .byte $70,$70,$60,$90,$90
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB
JumpSub: .byte $00,$00,$00,$00,$00
MoveX:
 lda M_SMB_X_SPEED
 jeq @done
 bmi :+
 lda #1
 bne @dir
:
 lda #2
@dir: sta M_MOVING_DIR
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
 plp
 lda M_TMP
 adc #0
 beq @done
 sta M_STEPS
 lda #1
 sta M_SIGN
 lda M_STEPS
 bpl @prepare
 eor #$FF
 clc
 adc #1
 sta M_STEPS
 lda #$FF
 sta M_SIGN
@prepare:
 lda M_STEPS
 sta M_TMP
@step:
 ldx G_PLAYER
 lda $04F0,x
 clc
 adc M_SIGN
 sta $04F0,x
 lda M_SIGN
 bmi @left
 bcc @advance
 inc $0500,x
 bne @advance
@left:
 bcs @advance
 dec $0500,x
@advance:
 dec M_TMP
 bne @step
 lda #0
 sta M_PROBE_X
 ; Maximum SMB motion is under four pixels, smaller than terrain or
 ; object widths. Test the final position and back out any penetration.
@test:
 jsr Side
 bcs @blocked
 ldx G_PLAYER
 jsr $F5A6
 bcs @blocked
 ldx G_PLAYER
 jsr $F721
 bcs @blocked
 lda M_PROBE_X
 bne @stop
@done: rts
@blocked:
 inc M_PROBE_X
 ldx G_PLAYER
 lda M_SIGN
 bmi @undoLeft
 lda $04F0,x
 bne :+
 dec $0500,x
:
 dec $04F0,x
 jmp @retry
@undoLeft:
 inc $04F0,x
 bne @retry
 inc $0500,x
@retry:
 dec M_STEPS
 bne @test
@stop:
 lda #0
 sta M_SMB_X_SPEED
 sta M_X_FRAC
 rts
Side:
 lda #7
 ldx M_SIGN
 bpl :+
 lda #$F8
:
 sta M_TILE
 tay
 lda #11
 jsr Point
 jsr IsWall
 bcs @done
 ldy M_TILE
 lda #$FC
 jsr Point
 jsr IsWall
 bcs @done
 lda M_TALL
 beq @free
 ldy M_TILE
 lda #$EC
 jsr Point
 jmp IsWall
@free: clc
@done: rts
IsWall:
 cmp #3
 bcc @no
 ; Exit volumes must be reachable by the native room-entry probes.
 ; Treating $05 as a wall stops Mario before his rear foot/head probe
 ; can enter a doorway, leaving the native room request unset.
 cmp #5
 beq @no
 cmp #6
 beq @no
 sec
 rts
@no: clc
 rts
StepY:
 ldx G_PLAYER
 lda M_SIGN
 bmi @up
 inc $0510,x
 lda $0510,x
 cmp #$F0
 bcc @done
 lda #0
 sta $0510,x
 inc $0520,x
 rts
@up:
 lda $0510,x
 bne :+
 lda #$F0
 sta $0510,x
 dec $0520,x
:
 dec $0510,x
@done: rts
MoveY:
 lda M_STATE
 jeq @done
 lda M_VY
 bpl @fall
 lda M_HELD
 and M_PREV
 and #$80
 bne @integrate
 ldx G_PLAYER
 lda $0520,x
 cmp M_Y_PAGE
 bne @fall
 lda M_JUMP_ORIGIN
 sec
 sbc $0510,x
 cmp #1
 bcc @integrate
@fall:
 lda M_FALL_FORCE
 sta M_GRAVITY
@integrate:
 lda M_Y_FRAC
 clc
 adc M_VY_FRAC
 sta M_Y_FRAC
 lda M_VY
 adc #0
 jeq @gravity
 sta M_STEPS
 lda #1
 sta M_SIGN
 lda M_STEPS
 bpl @step
 eor #$FF
 clc
 adc #1
 sta M_STEPS
 lda #$FF
 sta M_SIGN
@step:
 jsr StepY
 lda M_SIGN
 bmi @up
 ldx G_PLAYER
 lda #$FF
 sta $0560,x
 jsr $F62D
 bcc @terrain
 lda $11
 jeq @land
 cmp #5
 bcc :+
 lda #4
:
 sta M_TMP
 lda #$FF
 sta M_SIGN
@lift:
 jsr StepY
 dec M_TMP
 bne @lift
 jmp @land
@terrain:
 jsr Feet
 bcc @next
 ldx G_PLAYER
 lda $0510,x
 clc
 adc #12
 and #15
 bne @next
@land:
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 rts
@up:
 lda #$FC
 ldy M_TALL
 beq :+
 lda #$EC
:
 sta M_PROBE_Y
 ldy #$F9
 jsr Point
 jsr IsWall
 bcs @ceiling
 lda M_PROBE_Y
 ldy #6
 jsr Point
 jsr IsWall
 bcc @next
@ceiling:
 lda #1
 sta M_SIGN
 jsr StepY
 lda #0
 sta M_VY
 sta M_VY_FRAC
 jsr Feet
 bcc @ceilingFall
 ldx G_PLAYER
 lda $0510,x
 clc
 adc #12
 and #15
 jeq @land
@ceilingFall:
 jmp @gravity
@next:
 dec M_STEPS
 jne @step
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

Actions:
 ldx G_PLAYER
 lda $14,x
 and #$40
 bne @pressed
 ; B also runs. Holding it while approaching a map box may lift that
 ; box once it is in reach, without repeatedly throwing or firing.
 lda $56,x
 jne @done
 lda M_THROW
 jne @done
 lda M_HELD
 and #$40
 jeq @done
 lda M_INPUT_DIR
 jeq @done
 lda M_FACING
 cmp #2
 ldy #12
 bcc :+
 ldy #$F4
:
 lda #0
 jsr Point
 cmp #$0E
 jcc @done
 jmp @pickup
@pressed:
 lda $56,x
 beq @pickup
 ; Native side contact can pick up an object earlier in this movement
 ; update. The same B press must not immediately throw the new pickup.
 cmp M_ACTION_CARRY
 jne @done
 sta M_CONTACT_SLOT
 lda $0420,x
 sta $5C,x
 ; Native horizontal/up throw dispatch, including heavy objects and players.
 lda M_HELD
 and #8
 beq @horizontal
 lda $0340,x
 bne @throw
@horizontal: lda $0350,x
@throw:
 sta $0420,x
 lda #1
 sta $0410,x
 lda #0
 sta $0430,x
 lda #4
 sta $54,x
 ; Release through the native object dispatcher, after SMB movement.
 ; CD50 also runs native player gravity and rejects screen-edge throws.
 lda M_FACING
 cmp #2
 lda #$D0
 bcc :+
 lda #$90
:
 sta $0400,x
 jsr $CD66
 ldx G_PLAYER
 lda $56,x
 beq @released
 ; Complete the native heavy-object release and its wall interaction.
 lda #4
 sta $0430,x
 jsr $CD66
@released:
 lda M_HELD
 and #8
 bne :+
 ldy M_CONTACT_SLOT
 jsr CarryLift
:
 lda #8
 sta M_THROW
 rts
@pickup:
 ; Native object/body tests preserve crates, apples, metal boxes and co-op.
 lda M_FACING
 cmp #2
 lda #10
 bcc :+
 lda #13
:
 ; The native outer probes reach twelve pixels. Mario's wider left
 ; body stops at x+8, one pixel beyond the native inner probe.
 ldy #2
 jsr $F217
 lda $10
 cmp #$0E
 bcc @actors
 jsr $CB19
 ldx G_PLAYER
 lda $56,x
 bne @done
@actors:
 ldx G_PLAYER
 lda $14,x
 and #$40
 jeq @done
 jsr $F5A6
 ldx G_PLAYER
 lda $56,x
 bne @done
 ldy #2
@actor:
 lda $04D0,y
 bpl @next
 lda $0400,y
 and #8
 bne @next
 lda $04E0,y
 cmp #1
 beq @near
 cmp #$10
 bne @next
@near:
 sty G_SLOT
 sty $12
 jsr $F74C
 ldy G_SLOT
 bcc @next
 jsr $F868
 ldx G_PLAYER
 lda $56,x
 bne @done
@next:
 iny
 cpy #16
 bne @actor
 jsr SpawnFire
@done: rts
CarryHeight:
 ldx G_PLAYER
 ldy $56,x
 bne CarryLift
 rts
CarryLift:
 lda M_TALL
 beq @done
 lda $0490,y
 sec
 sbc #16
 bcs :+
 sbc #15
 pha
 lda $04A0,y
 sec
 sbc #1
 sta $04A0,y
 pla
:
 sta $0490,y
@done: rts
PickupObjectGate:
 ; A released object can still overlap its thrower's native box this
 ; frame. Do not catch it again while B remains held for running.
 txa
 pha
 tya
 pha
 txa
 lsr
 ror
 tax
 lda $682D,x
 beq @allow
 pla
 tay
 pla
 tax
 clc
 rts
@allow:
 pla
 tay
 pla
 tax
 tya
 ora #$80
 sta $56,x
 jmp $F86D
Collect:
 lda M_POWER
 cmp #2
 bcs @done
 inc M_POWER
 lda #32
 sta M_POWER_FREEZE
 ldx G_PLAYER
 lda #64
 sta $5E,x
@done: rts
Damage:
 lda M_STOMP_GRACE
 bne @done
 ldx G_PLAYER
 lda $5E,x
 bne @done
 lda M_POWER
 beq @die
 lda #0
 sta M_POWER
 sta M_CROUCH
 lda #32
 sta M_POWER_FREEZE
 lda #96
 sta $5E,x
 rts
@die:
 lda #0
 sta M_MAGIC
 ldx G_PLAYER
 lda #10
 sta $54,x
 rts
@done: rts
DeathGate:
 txa
 pha
 jsr LoadState
 lda #0
 sta M_MAGIC
 jsr SaveState
 pla
 tax
 lda $56,x
 beq :+
 jmp $D1E0
:
 jmp $D1FB

CollectibleGate:
 ; Queue the native flower pickup without swapping the live SMB state
 ; during a terrain probe. Keep the original flower counter and 1-ups.
 inc G_COLLECT_PENDING,x
 jmp $F3F5

ContactGate:
 ; Native enemy X, native player Y. Route back to this bank's own loop.
 stx G_SLOT
 tya
 tax
 jsr LoadState
 jsr Stomp
 bcs @save
 ldx G_SLOT
 ldy G_PLAYER
 lda $0420,y
 bne :+
 lda $56,y
 beq :+
 jsr $808E
 jmp @save
:
 jsr Damage
@save:
 jsr SaveState
 ldx G_SLOT
 jmp $8082
CollisionGate:
 stx G_SLOT
 ldy #0
@player:
 sty G_PLAYER
 lda $04D0,y
 bpl @next
 lda $54,y
 cmp #3
 bcs @next
 lda $0400,x
 bpl @next
 lda $0570,x
 and #$3F
 cmp #28
 bcs @next
 sta G_KIND
 jsr $F696
 lda $01
 bne @next
 ldy G_KIND
 lda $00
 cmp $FA18,y
 bcs @next
 ldy G_PLAYER
 jsr $F6DC
 sta G_TMP
 php
 lda G_PLAYER
 lsr
 ror
 tay
 lda $6804,y
 beq @small
 lda $681D,y
 bne @small
 ; Tall body's center is four pixels above the native anchor.
 ldy G_KIND
 lda $F9FC,y
 clc
 adc #4
 sta G_TMP2
 plp
 bcs @farther
 bcc @nearer
@small:
 ldy G_KIND
 lda $F9FC,y
 sec
 sbc #4
 sta G_TMP2
 plp
 bcc @farther
@nearer:
 lda G_TMP
 sec
 sbc #4
 bcs @test
 lda #0
 beq @test
@farther:
 lda G_TMP
 clc
 adc #4
@test:
 cmp G_TMP2
 bcs @next
 ldy G_PLAYER
 clc
 rts
@next:
 ldx G_SLOT
 ldy G_PLAYER
 iny
 cpy #2
 jne @player
 sec
 rts
Stomp:
 lda M_STOMP_CHAIN
 bne @descending
 lda M_VY
 bmi @no
@descending:
 lda M_STATE
 beq @no
 ldx G_SLOT
 lda $04E0,x
 cmp #$1C
 bcs @no
 cmp #1
 beq @no
 ; Native Y is the bottom/center of the enemy. A landing crosses its head.
 lda $0520,x
 cmp M_PREV_PAGE
 bne @no
 lda $0510,x
 sec
 sbc #12
 sta G_TMP
 lda M_PREV_Y
 clc
 adc #10
 cmp G_TMP
 bcc @hit
 sec
 sbc G_TMP
 cmp #9
 bcs @no
@hit:
 jsr StompKill
 lda #$FC
 sta M_VY
 lda #0
 sta M_VY_FRAC
 lda #1
 sta M_STATE
 lda #16
 sta M_STOMP_GRACE
 lda #1
 sta M_STOMP_CHAIN
 sec
 rts
@no:
 lda M_STOMP_GRACE
 beq :+
 sec
 rts
:
 clc
 rts
StompKill:
 ldx G_SLOT
 ldy G_PLAYER
 lda $0580,y
 sta $0580,x
 lda #$80
 sta $04D0,x
 lda #$1C
 sta $04E0,x
 lda #0
 sta $0570,x
 lda #$A8
 sta $0530,x
 sta $0550,x
 lda #5
 sta $0540,x
 sta $0560,x
 lda #$16
 jmp $F379

SpawnFire:
 lda M_POWER
 cmp #2
 jne @done
 ldx G_PLAYER
 lda G_FIRE_LIFE,x
 beq @slot
 inx
 inx
 lda G_FIRE_LIFE,x
 jne @done
@slot:
 lda #100
 sta G_FIRE_LIFE,x
 lda #4
 sta G_FIRE_VY,x
 lda #0
 sta G_FIRE_FRAC,x
 lda M_FACING
 sta G_FIRE_DIR,x
 ldy G_PLAYER
 tya
 sta G_FIRE_OWNER,x
 lda $04F0,y
 sta G_FIRE_X,x
 lda $0500,y
 sta G_FIRE_XH,x
 lda $0510,y
 sta G_FIRE_Y,x
 lda $0520,y
 sta G_FIRE_YH,x
 lda #8
 sta M_THROW
 stx G_INDEX
 ldy #15
@find:
 lda $04D0,y
 bpl @proxy
 dey
 cpy #1
 bne @find
 lda #0
 sta G_FIRE_LIFE,x
 rts
@proxy:
 tya
 sta G_PROXY,x
 lda #$80
 sta $04D0,y
 lda #$D8
 sta $0400,y
 lda #1
 sta $04E0,y
 lda #$22
 sta $0420,y
 lda #0
 sta $0570,y
 sta $0480,y
 sta $0490,y
 sta $04A0,y
 sta $04B0,y
 sta $0410,y
 sta $0430,y
 lda G_FIRE_DIR,x
 sta $0580,y
 jsr SyncProxy
@done: rts
ActorGate:
 ldy #3
@check:
 txa
 cmp G_PROXY,y
 bne @next
 lda G_FIRE_LIFE,y
 beq @next
 lda $04E0,x
 cmp #1
 bne @expired
 lda $0400,x
 and #8
 beq @expired
 jmp $8082
@expired:
 lda #0
 sta G_FIRE_LIFE,y
 lda #$FF
 sta G_PROXY,y
@next:
 dey
 bpl @check
 ldy $04E0,x
 jmp $800C
ObjectHitGate:
 stx $05
 ldy #2
 jsr $F97B
 bcs @done
 php
 pha
 txa
 pha
 sty G_NATIVE_HIT
 ldx #3
@find:
 lda G_PROXY,x
 cmp G_NATIVE_HIT
 bne @next
 lda G_FIRE_LIFE,x
 beq @next
 lda #0
 sta G_FIRE_LIFE,x
 ldy G_NATIVE_HIT
 sta $04D0,y
 jmp @restore
@next:
 dex
 bpl @find
@restore:
 pla
 tax
 pla
 plp
 ldy G_NATIVE_HIT
@done: rts
SyncProxy:
 ldy G_PROXY,x
 cpy #$FF
 beq @done
 lda G_FIRE_X,x
 sta $04F0,y
 lda G_FIRE_XH,x
 sta $0500,y
 lda G_FIRE_Y,x
 sta $0510,y
 lda G_FIRE_YH,x
 sta $0520,y
@done: rts
ClearProxy:
 ldy G_PROXY,x
 cpy #$FF
 beq @done
 lda $0400,y
 and #8
 beq @forget
 lda $04E0,y
 cmp #1
 bne @forget
 lda #0
 sta $04D0,y
@forget:
 lda #$FF
 sta G_PROXY,x
@done: rts
ResetGate:
 lda #0
 sta G_READY
 sta G_ITEM_ACTIVE
 sta G_ITEM_ACTIVE+1
 sta G_COLLECT_PENDING
 sta G_COLLECT_PENDING+1
 ldx #3
@fire:
 sta G_FIRE_LIFE,x
 dex
 bpl @fire
 lda #$FF
 ldx #3
@proxy:
 sta G_PROXY,x
 dex
 bpl @proxy
 sta $6837
 sta $68B7
 ldx #$0F
@actors:
 lda #0
 sta $04D0,x
 lda #$FF
 sta $0590,x
 dex
 cpx #1
 bne @actors
 rts
Fireballs:
 ldx #3
@fire:
 lda G_FIRE_LIFE,x
 jeq @next
 dec G_FIRE_LIFE,x
 lda G_FIRE_DIR,x
 cmp #2
 beq @left
 lda G_FIRE_X,x
 clc
 adc #4
 sta G_FIRE_X,x
 bcc @vertical
 inc G_FIRE_XH,x
 jmp @vertical
@left:
 lda G_FIRE_X,x
 sec
 sbc #4
 sta G_FIRE_X,x
 bcs @vertical
 dec G_FIRE_XH,x
@vertical:
 stx G_INDEX
 jsr FirePoint
 jsr Tile
 cmp #3
 bcc @moveY
 cmp #6
 beq @moveY
 ldx G_INDEX
 lda #0
 sta G_FIRE_LIFE,x
 jmp @next
@moveY:
 ldx G_INDEX
 lda G_FIRE_VY,x
 sta G_TMP2
 clc
 adc G_FIRE_Y,x
 ldy G_TMP2
 bmi @upY
 cmp #$F0
 bcc @storeY
 adc #$0F
 inc G_FIRE_YH,x
 jmp @storeY
@upY:
 bcs @storeY
 sbc #15
 dec G_FIRE_YH,x
@storeY:
 sta G_FIRE_Y,x
 lda G_FIRE_FRAC,x
 clc
 adc #$50
 sta G_FIRE_FRAC,x
 bcc :+
 inc G_FIRE_VY,x
:
 lda G_FIRE_VY,x
 cmp #5
 bne :+
 lda #4
 sta G_FIRE_VY,x
:
 jsr FirePoint
 jsr Tile
 cmp #2
 bcc @enemies
 ldx G_INDEX
 lda G_FIRE_VY,x
 bmi @enemies
 lda #$FD
 sta G_FIRE_VY,x
 lda #0
 sta G_FIRE_FRAC,x
 lda G_FIRE_Y,x
 and #$F0
 sec
 sbc #1
 bcs :+
 sbc #15
 dec G_FIRE_YH,x
:
 sta G_FIRE_Y,x
@enemies:
 ldx G_INDEX
 jsr SyncProxy
@next:
 lda G_FIRE_LIFE,x
 bne :+
 jsr ClearProxy
:
 dex
 jpl @fire
 rts
FirePoint:
 lda G_FIRE_X,x
 sta G_X
 lda G_FIRE_XH,x
 sta G_XH
 lda G_FIRE_Y,x
 sta G_Y
 lda G_FIRE_YH,x
 sta G_YH
 rts

SpriteGate:
 cpx #2
 bcc :+
 lda $0400,x
 jmp $812C
:
 rts
ClearGate:
 pha
 lda #0
 sta G_READY
 pla
 ldx $97
 cpx #4
 jmp $C222
DmaGate:
 lda #2
 ldx G_READY
 beq :+
 lda #$64
:
 sta $4014
 rts
DrawGate:
 jsr $8000
 jsr Fireballs
 jsr Palettes
 jsr Compose
 rts
Palettes:
 ; Keep native palette RAM intact. Hardware gets a separate copy with
 ; Mario's colors in an unused green/yellow slot whenever possible.
 ldx #31
@copy:
 lda $0300,x
 sta G_PALETTE,x
 dex
 bpl @copy
 ldx #3
@map:
 txa
 sta G_PAL_MAP,x
 dex
 bpl @map
 ; Compose records native palette use while copying sprites. Reuse
 ; that count next frame instead of scanning the OAM page twice.
 lda #3
 ldx $04D1
 bmi @reserve
 ldx G_PAL_USE+2
 cpx G_PAL_USE+3
 bcs @reserve
 lda #2
@reserve:
 sta G_PLAYER_PAL
 eor #1
 sta G_PLAYER_PAL+1
 tax
 sta G_PAL_MAP+2
 sta G_PAL_MAP+3
 lda $04D1
 bpl @colors
 lda #1
 sta G_PAL_MAP+2
 sta G_PAL_MAP+3
@colors:
 ldx #0
@player:
 lda $04D0,x
 bpl @next
 lda G_PLAYER_PAL,x
 asl
 asl
 clc
 adc #$11
 sta G_TMP2
 txa
 lsr
 ror
 tay
 lda $6804,y
 cmp #2
 lda #$16
 bcc :+
 lda #$37
:
 ldy G_TMP2
 cpx #0
 beq :+
 cmp #$37
 beq :+
 lda #$17
:
 sta G_PALETTE,y
 lda #$27
 sta G_PALETTE+1,y
 lda #$18
 pha
 txa
 lsr
 ror
 tay
 lda $6804,y
 cmp #2
 pla
 bcc @third
 lda #$16
 cpx #0
 beq @third
 lda #$19
@third:
 ldy G_TMP2
 sta G_PALETTE+2,y
@next:
 inx
 cpx #2
 bne @player
 lda #1
 sta $18
 rts
PaletteUpload:
 lda G_READY
 jeq @native
 .repeat 32,I
 lda G_PALETTE+I
 sta $2007
 .endrepeat
 ldx #32
 ldy #0
 jmp $C078
@native:
 lda $0300,x
 sta $2007
 inx
 dey
 bne @native
 jmp $C078
Compose:
 ; Keep native sprite positions and append Mario/Luigi. Only copy the
 ; used native OAM prefix; reserve room for both players and fireballs.
 lda #216
 ldx $04D1
 bpl :+
 lda #176
:
 ldx #1
@reserveItems:
 ldy G_ITEM_ACTIVE,x
 beq :+
 sec
 sbc #16
:
 dex
 bpl @reserveItems
 sta G_NATIVE_LIMIT
 ; $97 is zero for a full native page. Bound the prefix once so the
 ; hot sprite-copy loop needs only one length comparison per record.
 lda $97
 beq :+
 cmp G_NATIVE_LIMIT
 bcs :+
 sta G_NATIVE_LIMIT
:
 lda #0
 sta G_PAL_USE+2
 sta G_PAL_USE+3
 ldy #0
@native:
 lda $0200,y
 sta $6400,y
 lda $0201,y
 sta $6401,y
 lda $0202,y
 and #2
 beq @identity
 lda $0202,y
 and #1
 tax
 inc G_PAL_USE+2,x
 lda $0202,y
 and #$FC
 ora G_PAL_MAP+2
 jmp @attribute
@identity:
 lda $0202,y
@attribute:
 sta $6402,y
 lda $0203,y
 sta $6403,y
 iny
 iny
 iny
 iny
 cpy G_NATIVE_LIMIT
 bcc @native
@copied:
 sty G_OAM
 ; Native hearts stay at their original HUD positions.
 lda $6804
 cmp #2
 bcs @rightHearts
 lda #$F8
 sta $6410
 ldx $6804
 bne @rightHearts
 sta $640C
@rightHearts:
 lda $6884
 cmp #2
 bcs @players
 lda #$F8
 sta $6424
 ldx $6884
 bne @players
 sta $6420
@players:
 ldx #0
@player:
 lda $04D0,x
 bpl @nextPlayer
 stx G_PLAYER
 txa
 lsr
 ror
 sta G_OFFSET
 tax
 ; Rendering uses only these fields, not the whole physics state.
 lda $6802,x
 sta $6902
 lda $6804,x
 sta $6904
 lda $6805,x
 sta $6905
 lda $6806,x
 sta $6906
 lda $680B,x
 sta $690B
 lda $680C,x
 sta $690C
 lda $6811,x
 sta $6911
 lda $6812,x
 sta $6912
 lda $681D,x
 sta $691D
 lda $6828,x
 sta $6928
 lda $6829,x
 sta $6929
 lda $6835,x
 sta $6935
 ldx G_PLAYER
 jsr Render
 ldx G_OFFSET
 lda M_ANIM_TIMER
 sta $6828,x
 lda M_ANIM
 sta $6829,x
 ldx G_PLAYER
@nextPlayer:
 inx
 cpx #2
 bne @player
 jsr DrawItems
 jsr DrawFire
 ldx G_OAM
 beq @ready
 lda #$F8
@blank:
 sta $6400,x
 inx
 inx
 inx
 inx
 bne @blank
@ready:
 lda #1
 sta G_READY
 rts
Screen:
 ; G_X/XH/Y/YH world point -> screen anchors, carry if not visible.
 lda G_X
 sec
 sbc $FC
 sta G_ANCHOR_X
 lda G_XH
 sbc $FD
 bne @outside
 lda G_Y
 sec
 sbc $FA
 bcs :+
 sbc #15
 clc
:
 sta G_ANCHOR_Y
 lda G_YH
 sbc $FB
 bne @outside
 clc
 rts
@outside: sec
 rts
Render:
 ldx G_PLAYER
 lda $0500,x
 sta G_XH
 lda $04F0,x
 sta G_X
 lda $0510,x
 sta G_Y
 lda $0520,x
 sta G_YH
 jsr Screen
 jcs @done
 lda $54,x
 cmp #12
 jeq @done
 lda $56,x
 beq :+
 lda M_HELD
 and #4
 beq :+
 lda $0420,x
 jeq @done
:
 lda $5E,x
 beq @frame
 and #4
 jne @done
@frame:
 jsr SelectFrame
 sta G_POSE
 lda #0
 sta G_FLIP
 lda M_FACING
 cmp #2
 bne :+
 lda #$40
 sta G_FLIP
:
 lda G_POSE
 asl
 asl
 asl
 asl
 sta $00
 lda G_POSE
 lsr
 lsr
 lsr
 lsr
 clc
 adc #>FrameTable
 sta $01
 lda $00
 clc
 adc #<FrameTable
 sta $00
 bcc :+
 inc $01
:
 lda G_PLAYER
 tax
 lda G_PLAYER_PAL,x
 sta G_ATTR
 lda G_ANCHOR_X
 sec
 sbc #8
 sta G_ANCHOR_X
 lda G_ANCHOR_Y
 sec
 sbc #21
 sta G_ANCHOR_Y
 lda G_FLIP
 lsr
 lsr
 lsr
 sta G_TMP2
 ; Cache both screen columns once, then emit a complete sprite row.
 lda G_ANCHOR_X
 clc
 adc G_TMP2
 sta G_XH
 lda G_TMP2
 eor #8
 clc
 adc G_ANCHOR_X
 sta G_YH
 ldy #0
 ; Small frames have four transparent tiles above their actual body.
 lda G_POSE
 cmp #12
 bcc @shortRow
 cmp #24
 bcs @shortRow
 ldy #8
 bne @rows
@shortRow:
 cmp #10
 beq @skipRow
 cmp #25
 bne @rows
@skipRow:
 ldy #4
@rows:
 tya
 asl
 clc
 adc G_ANCHOR_Y
 sta G_Y
@row:
 lda G_Y
 cmp #$EF
 bcs @skipPair
 ldx G_OAM
 .repeat 2,I
 lda G_Y
 sta $6400,x
 lda ($00),y
 sta $6401,x
 iny
 lda ($00),y
 eor G_FLIP
 ora G_ATTR
 sta $6402,x
 iny
 .if I=0
 lda G_XH
 .else
 lda G_YH
 .endif
 sta $6403,x
 inx
 inx
 inx
 inx
 .endrepeat
 stx G_OAM
 jmp @advanceRow
@skipPair:
 iny
 iny
 iny
 iny
@advanceRow:
 lda G_Y
 clc
 adc #8
 sta G_Y
 cpy #16
 bne @row
@done: rts
SelectFrame:
 ldx G_PLAYER
 lda $54,x
 cmp #10
 bne :+
 lda #22
 rts
:
 lda M_POWER_FREEZE
 beq @normal
 and #8
 beq @normal
 lda #25
 rts
@normal:
 lda M_POWER
 beq @small
 lda M_CROUCH
 beq :+
 lda #10
 rts
:
 lda M_STATE
 ora $56,x
 bne @bigJump
 lda M_SMB_X_SPEED
 beq @bigStand
 lda M_INPUT_DIR
 beq @walk
 cmp M_MOVING_DIR
 beq @walk
 lda #3
 rts
@bigStand: lda #24
 rts
@bigJump: lda #4
 rts
@small:
 lda M_STATE
 ora $56,x
 bne @smallJump
 lda M_SMB_X_SPEED
 beq @smallStand
 lda M_INPUT_DIR
 beq @walk
 cmp M_MOVING_DIR
 beq @walk
 lda #15
 rts
@smallStand: lda #23
 rts
@smallJump: lda #16
 rts
@walk:
 lda M_ANIM_TIMER
 beq @advance
 dec M_ANIM_TIMER
 jmp @anim
@advance:
 lda M_ANIM_SET
 sta M_ANIM_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc @anim
 lda #0
 sta M_ANIM
@anim:
 lda M_ANIM
 ldx M_POWER
 bne :+
 clc
 adc #12
:
 rts
DrawItems:
 ldx #0
@item:
 stx G_INDEX
 lda G_ITEM_ACTIVE,x
 jeq @next
 lda G_ITEM_X,x
 sta G_X
 lda G_ITEM_XH,x
 sta G_XH
 lda G_ITEM_Y,x
 sta G_Y
 lda G_ITEM_YH,x
 sta G_YH
 jsr Screen
 jcs @next
 ; Either player can collect a shared supply.
 ldx #0
@collect:
 lda $04D0,x
 bpl @other
 lda $54,x
 cmp #6
 bcs @other
 lda $0500,x
 cmp G_XH
 bne @other
 lda $0520,x
 cmp G_YH
 bne @other
 lda $04F0,x
 sec
 sbc G_X
 clc
 adc #12
 cmp #25
 bcs @other
 lda $0510,x
 sec
 sbc G_Y
 clc
 adc #16
 cmp #33
 bcs @other
 jsr LoadState
 jsr Collect
 jsr SaveState
 ldx G_INDEX
 lda #0
 sta G_ITEM_ACTIVE,x
 jmp @next
@other:
 inx
 cpx #2
 bne @collect
 ldx G_INDEX
 lda G_ITEM_KIND,x
 asl
 asl
 asl
 sta G_KIND
 lda #0
 sta G_ATTR
 jsr ItemSprite
@next:
 ldx G_INDEX
 inx
 cpx #2
 jne @item
 rts
ItemSprite:
 ldy #0
@tile:
 ldx G_OAM
 lda G_ANCHOR_Y
 sec
 sbc #5
 sta G_TMP
 tya
 and #4
 asl
 clc
 adc G_TMP
 sta $6400,x
 tya
 clc
 adc G_KIND
 tay
 lda ItemTable,y
 sta $6401,x
 iny
 lda ItemTable,y
 ora G_ATTR
 sta $6402,x
 dey
 tya
 sec
 sbc G_KIND
 tay
 and #2
 asl
 asl
 sta G_TMP
 lda G_ANCHOR_X
 sec
 sbc #8
 clc
 adc G_TMP
 sta $6403,x
 inc G_OAM
 inc G_OAM
 inc G_OAM
 inc G_OAM
 iny
 iny
 cpy #8
 bne @tile
 rts
DrawFire:
 ldx #3
@fire:
 stx G_INDEX
 lda G_FIRE_LIFE,x
 beq @next
 lda G_FIRE_X,x
 sta G_X
 lda G_FIRE_XH,x
 sta G_XH
 lda G_FIRE_Y,x
 sta G_Y
 lda G_FIRE_YH,x
 sta G_YH
 jsr Screen
 bcs @next
 ldx G_OAM
 lda G_ANCHOR_Y
 sta $6400,x
 lda ItemTable+16
 sta $6401,x
 ldx G_INDEX
 ldy G_FIRE_OWNER,x
 lda G_PLAYER_PAL,y
 ldx G_OAM
 sta $6402,x
 lda G_ANCHOR_X
 sta $6403,x
 inc G_OAM
 inc G_OAM
 inc G_OAM
 inc G_OAM
@next:
 ldx G_INDEX
 dex
 bpl @fire
 rts
ItemTable: .incbin "../build/items.bin"
.include "smb-land.inc"
.assert * <= $8000,error,"Work RAM code overflow"
.segment "FRAMES"
FrameTable: .incbin "../build/frames.bin"

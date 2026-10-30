; Instantiated once per controller: persistent SMB state is independent.
.include "state.inc"
Init:
 lda M_MAGIC
 cmp #$4D
 beq @ready
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
 sta M_LAST_FRAME
 sta M_LAST_WORLD
 lda #$4D
 sta M_MAGIC
@ready:
 rts
Move:
 jsr Init
 lda N_CURRENT_LEVEL
 cmp M_LAST_WORLD
 beq @same
 sta M_LAST_WORLD
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_X_FRAC
@same:
 lda #0
 sta M_SCRIPT
 lda #0
 sta M_STOMP_CHAIN
 lda M_STOMP_GRACE
 beq :+
 dec M_STOMP_GRACE
:
 lda N_CONTROLLER_STATE+P
 sta M_HELD
 lda N_SPRITE_Y_POS+P
 sta M_PREV_Y
 lda M_POWER_FREEZE
 beq @move
 dec M_POWER_FREEZE
 jmp @sync
@move:
 lda M_THROW
 beq :+
 dec M_THROW
:
 lda M_SWIM_TIMER
 beq :+
 dec M_SWIM_TIMER
:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 jsr Environment
 jsr Body
 jsr Support
 lda M_HELD
 and #3
 sta M_INPUT_DIR
 lda M_STATE
 bne @crouchDone
 lda #0
 sta M_CROUCH
 lda M_HELD
 and #4
 beq @crouchDone
 lda M_INPUT_DIR
 beq @duck
 lda #0
 sta M_INPUT_DIR
 beq @crouchDone
@duck:
 lda M_POWER
 beq @crouchDone
 inc M_CROUCH
 lda #0
 sta M_INPUT_DIR
@crouchDone:
 jsr TryStand
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
 beq @pos
@friction:
 jsr ImposeFriction
@pos:
 jsr MoveX
 jsr MoveY
@sync:
 lda M_VY
 sta N_PLAYER_Y_FAST_VELOCITY+P
 lda M_VY_FRAC
 sta N_PLAYER_Y_FRACT_VELOCITY+P
 lda M_STATE
 sta N_PLAYER_JUMP_STATUS+P
 lda #3
 ldx M_CROUCH
 beq :+
 lda #2
:
 sta N_PLAYER_SPRITE_SEQUENCE+P
 lda #1
 ldx M_CROUCH
 beq :+
 lda #$17
:
 sta N_PLAYER_SPRITE_CODE+P
 lda M_FACING
 cmp #2
 lda #0
 bcc :+
 lda #$40
:
 sta N_PLAYER_SPRITE_FLIP+P
 lda M_HELD
 sta M_PREV
 ldx #P
 rts
SyncNative:
 jsr Init
 ; A growth pickup can overlap a native base-room walk. Native scripts
 ; own movement here, but Mario's independent morph timer must still run.
 lda M_POWER_FREEZE
 beq :+
 dec M_POWER_FREEZE
:
 lda #1
 sta M_SCRIPT
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_X_FRAC
 sta M_CROUCH
 sta M_SWIMMING
 lda N_CONTROLLER_STATE+P
 sta M_PREV
 lda N_PLAYER_JUMP_STATUS+P
 beq :+
 lda #2
:
 sta M_STATE
 lda N_PLAYER_Y_FAST_VELOCITY+P
 sta M_VY
 lda N_PLAYER_Y_FRACT_VELOCITY+P
 sta M_VY_FRAC
 lda N_PLAYER_JUMP_COEFFICIENT+P
 sta M_Y_FRAC
 lda #$70
 sta M_FALL_FORCE
 lda N_PLAYER_SPRITE_FLIP+P
 and #$40
 beq :+
 lda #2
 bne :++
:
 lda #1
:
 sta M_FACING
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
TryStand:
 lda M_POWER
 beq @done
 lda M_CROUCH
 ora N_PLAYER_HIDDEN+P
 ora N_LEVEL_LOCATION_TYPE
 bne @done
 lda N_SPRITE_Y_POS+P
 sec
 sbc #19
 bcc @done
 sta M_PROBE_Y
 lda N_SPRITE_X_POS+P
 sec
 sbc #7
 tay
 lda M_PROBE_Y
 jsr Tile
 bmi @duck
 lda N_SPRITE_X_POS+P
 clc
 adc #6
 tay
 lda M_PROBE_Y
 jsr Tile
 bpl @done
@duck:
 lda #1
 sta M_CROUCH
@done:
 rts
Tile:
 ; Same packed native collision map and 240-pixel wrap, with direct
 ; column extraction tables instead of repeated shifts in every probe.
 sta M_LOOKUP_Y
 stx $11
 tya
 clc
 adc N_HORIZONTAL_SCROLL
 sta M_PROBE_X
 lda N_PPUCTRL_SETTINGS
 and #1
 adc #0
 and #1
 .repeat 6
 asl
 .endrepeat
 sta M_LOOKUP_ROW
 lda M_LOOKUP_Y
 cmp #$E0
 bcs @empty
 clc
 adc N_VERTICAL_SCROLL
 bcs @wrap
 cmp #$F0
 bcc @row
@wrap:
 adc #$0F
@row:
 and #$F0
 lsr
 lsr
 ora M_LOOKUP_ROW
 sta M_LOOKUP_ROW
 lda M_PROBE_X
 .repeat 4
 lsr
 .endrepeat
 tay
 lsr
 lsr
 ora M_LOOKUP_ROW
 tax
 lda N_BG_COLLISION_DATA,x
 tax
 tya
 and #3
 beq @column0
 cmp #1
 beq @column1
 cmp #2
 beq @column2
 lda Collision3,x
 jmp @return
@column0:
 lda Collision0,x
 jmp @return
@column1:
 lda Collision1,x
 jmp @return
@column2:
 lda Collision2,x
 jmp @return
@empty:
 lda #0
@return:
 ldx $11
 ora #0
 rts
Environment:
 jsr Feet
 cmp #2
 beq @water
 cmp #0
 beq @leave
 lda M_SWIMMING
 beq @leave
 ; A shore cell can replace water while the feet are still below its
 ; top. Retain buoyancy until ShoreStep can put the whole body on land.
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 adc N_VERTICAL_SCROLL
 and #$0F
 bne @water
@leave:
 lda M_SWIMMING
 beq @dry
 lda #$70
 sta M_FALL_FORCE
@dry:
 lda #0
 sta M_SWIMMING
 sta M_WATER_LEVEL
 lda #1
 sta M_AREA_TYPE
 rts
@water:
 lda M_SWIMMING
 bne @alreadyWet
 ; SMB's high-speed airborne branch retains its land-running limit.
 ; Contra can enter a pool at that speed, so switch momentum to the
 ; normal SMB water limit at the actual dry-to-wet contact boundary.
 lda #0
 sta M_RUNNING_SPEED
 sta M_RUNNING_TIMER
 lda M_SMB_X_SPEED
 bmi @leftEntry
 cmp MaxRightXSpdData+1
 bcc @surface
 lda MaxRightXSpdData+1
 sta M_SMB_X_SPEED
 sta M_SMB_X_ABS
 bne @entryForce
@leftEntry:
 cmp MaxLeftXSpdData+1
 bcs @surface
 lda MaxLeftXSpdData+1
 sta M_SMB_X_SPEED
 lda MaxRightXSpdData+1
 sta M_SMB_X_ABS
@entryForce:
 lda #0
 sta M_SMB_X_FORCE
 jmp @surface
@alreadyWet:
 lda M_WATER_LEVEL
 bne @swim
@surface:
 ; Capture the surface where water was entered. Contra wraps vertical
 ; nametable coordinates at 240, including the Jungle's $E0 scroll.
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 clc
 adc N_VERTICAL_SCROLL
 bcs @wrap
 cmp #$F0
 bcc @row
@wrap:
 adc #$0F
@row:
 and #$F0
 sec
 sbc N_VERTICAL_SCROLL
 bcs :+
 clc
 adc #$F0
:
 sta M_WATER_LEVEL
@swim:
 lda #1
 sta M_SWIMMING
 lda #0
 sta M_AREA_TYPE
 lda #$0A
 sta M_FALL_FORCE
 lda M_VY
 bmi @done
 cmp #2
 bcc @done
 lda #1
 sta M_VY
@done: rts
Feet:
 lda N_PLAYER_HIDDEN+P
 bne @empty
 lda N_LEVEL_LOCATION_TYPE
 beq @outdoor
 lda #$A8
 ldx N_LEVEL_LOCATION_TYPE
 bpl :+
 lda #$C9
:
 cmp N_SPRITE_Y_POS+P
 beq @floor
 bcs @empty
@floor:
 lda #1
 rts
@empty:
 lda #0
 rts
@outdoor:
 ldy N_SPRITE_X_POS+P
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 bcs @empty
 jsr Tile
 cmp #1
 beq @contact
 cmp #$80
 beq @contact
 sta M_OUTPUT_A
 ; Support the outer foot after stepping onto an edge, even before the
 ; centre has crossed it. Only the top boundary supplies edge support.
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 adc N_VERTICAL_SCROLL
 and #$0F
 bne @centre
 lda N_SPRITE_X_POS+P
 sec
 sbc #8
 tay
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 jsr Tile
 cmp #1
 beq @contact
 cmp #$80
 beq @contact
 lda N_SPRITE_X_POS+P
 clc
 adc #7
 tay
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 jsr Tile
 cmp #1
 beq @contact
 cmp #$80
 beq @contact
@centre:
 lda M_OUTPUT_A
@contact:
 ora #0
 rts
Support:
 lda M_VY
 bmi @fall
 jsr Feet
 cmp #2
 beq @fall
 cmp #0
 beq @platform
 lda N_LEVEL_LOCATION_TYPE
 bne @floor
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 adc N_VERTICAL_SCROLL
 and #$0F
 bne @fall
@floor:
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 rts
@platform:
 lda N_PLAYER_ON_ENEMY+P
 bne @floor
@fall:
 lda M_STATE
 bne @done
 lda #2
 sta M_STATE
 lda M_FALL_FORCE
 sta M_GRAVITY
@done:
 rts
TryDrop:
 ; A fresh Down+A lowers the feet past this one-way surface. Keep
 ; Contra's check for a safe destination below horizontal platforms.
 lda M_STATE
 bne @normal
 lda M_HELD
 and #4
 beq @normal
 lda M_SWIMMING
 ora N_LEVEL_LOCATION_TYPE
 bne @normal
 jsr Feet
 cmp #1
 bne @normal
 ldx #P
 jsr N_can_player_drop_down
 bcs @handled
 inc N_SPRITE_Y_POS+P
 lda #2
 sta M_STATE
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta M_Y_FRAC
 sta N_PLAYER_ON_ENEMY+P
 lda #$70
 sta M_GRAVITY
 sta M_FALL_FORCE
@handled:
 clc
 rts
@normal:
 sec
 rts
Jump:
 lda M_STATE
 beq @button
 lda M_SWIMMING
 beq @done
 lda M_SWIM_TIMER
 bne @button
 lda M_VY
 bmi @done
@button:
 lda M_HELD
 and #$80
 beq @done
 and M_PREV
 bne @done
 jsr TryDrop
 bcc @done
 ldy #0
 lda M_SMB_X_ABS
 cmp #9
 bcc @force
 iny
 cmp #$10
 bcc @force
 iny
 cmp #$19
 bcc @force
 iny
 cmp #$1C
 bcc @force
 iny
@force:
 lda M_SWIMMING
 beq :+
 ldy #5
:
 lda JumpForce,y
 sta M_GRAVITY
 lda FallForce,y
 sta M_FALL_FORCE
 lda JumpSpeed,y
 sta M_VY
 lda #0
 sta M_VY_FRAC
 lda M_SWIMMING
 beq :+
 lda #$80
 sta M_VY_FRAC
:
 lda #0
 sta M_Y_FRAC
 lda N_SPRITE_Y_POS+P
 sta M_JUMP_ORIGIN
 lda #1
 sta M_STATE
 lda #32
 sta M_SWIM_TIMER
@done: rts
JumpForce: .byte $20,$20,$1E,$28,$28,$0D
FallForce: .byte $70,$70,$60,$90,$90,$0A
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB,$FE
MoveX:
 ; Native animation, platforms and scripted transitions also read this
 ; velocity. A frame with no SMB pixel step must not retain yesterday's
 ; leftward/rightward step after friction has stopped the character.
 lda #0
 sta N_PLAYER_X_VELOCITY+P
 sta M_DX
 lda N_SPRITE_X_POS+P
 sta M_START_X
 lda N_FRAME_SCROLL
 sta G_OLD_SCROLL
 lda #0
 sta M_SCROLL
 lda M_SMB_X_SPEED
 jeq @boost
 bmi @left
 lda #1
 bne @dir
@left: lda #2
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
@boost:
 clc
 adc N_PLAYER_FAST_X_VEL_BOOST+P
 jeq @done
 ; A frame crosses less than one collision cell. Probe its endpoint once;
 ; use pixel steps only to resolve a blocked endpoint at the exact edge.
 sta M_STEPS
 sta M_DX
 bmi @tryLeft
 lda #1
 bne @trySign
@tryLeft:
 lda #$FF
@trySign:
 sta M_SIGN
 lda M_START_X
 clc
 adc M_DX
 sta N_SPRITE_X_POS+P
 ldx M_SIGN
 bmi @endpointLeft
 cmp #$E7
 bcs @pixelFallback
 bcc @endpointReady
@endpointLeft:
 cmp #$1A
 bcc @pixelFallback
@endpointReady:
 jsr ShoreStep
 bcs @pixelFallback
 jsr Side
 bcs @pixelFallback
 jmp @done
@pixelFallback:
 lda M_START_X
 sta N_SPRITE_X_POS+P
 lda #0
 sta M_DX
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
 lda N_SPRITE_X_POS+P
 clc
 adc M_SIGN
 sta N_SPRITE_X_POS+P
 ldx M_SIGN
 bmi @pixelLeft
 cmp #$E7
 bcs @undoBlocked
 bcc @pixelReady
@pixelLeft:
 cmp #$1A
 bcc @undoBlocked
@pixelReady:
 jsr ShoreStep
 bcs @sideResult
 jsr Side
@sideResult:
 bcs @blocked
 lda M_DX
 clc
 adc M_SIGN
 sta M_DX
 jmp @nextX
@undoBlocked:
 lda N_SPRITE_X_POS+P
 sec
 sbc M_SIGN
 sta N_SPRITE_X_POS+P
 jmp @blocked
@nextX:
 dec M_STEPS
 bne @step
@done:
 lda M_START_X
 sta N_SPRITE_X_POS+P
 lda #0
 sta N_FRAME_SCROLL
 sta N_PLAYER_FRAME_SCROLL+P
 sta N_PLAYER_FAST_X_VEL_BOOST+P
 lda M_DX
 sta N_PLAYER_X_VELOCITY+P
 beq @scrolled
 lda N_LEVEL_SCROLLING_TYPE
 bne @verticalX
 lda #1
 sta G_CUSTOM_MOVE
 ldx #P
 jsr N_calc_player_x_vel
 lda N_FRAME_SCROLL
 sta M_SCROLL
 lda #0
 sta G_CUSTOM_MOVE
 jmp @scrolled
@verticalX:
 lda N_SPRITE_X_POS+P
 clc
 adc M_DX
 sta N_SPRITE_X_POS+P
@scrolled:
 lda M_SCROLL
 cmp G_OLD_SCROLL
 bcs :+
 lda G_OLD_SCROLL
:
 sta N_FRAME_SCROLL
 lda M_SCROLL
 beq :+
 lda #1
:
 sta N_PLAYER_FRAME_SCROLL+P
 rts
@blocked:
 ; The last trial pixel was rejected; keep only earlier accepted steps.
 lda #0
 sta M_SMB_X_SPEED
 sta M_X_FRAC
 jmp @done
ShoreStep:
 ; Contra lets a swimmer walk up one 16-pixel shore cell without A.
 ; Probe the advancing foot before the usual side wall test; both body
 ; edges must fit at the raised position before committing the step.
 lda M_SWIMMING
 jeq @free
 lda N_PLAYER_HIDDEN+P
 ora N_LEVEL_LOCATION_TYPE
 jne @free
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 jcs @free
 sta M_PROBE_Y
 lda #7
 ldx M_SIGN
 bpl :+
 lda #$F8
:
 clc
 adc N_SPRITE_X_POS+P
 sta M_TILE
 tay
 lda M_PROBE_Y
 jsr Tile
 cmp #1
 beq @surface
 cmp #$80
 beq @surface
 dec M_PROBE_Y
 ldy M_TILE
 lda M_PROBE_Y
 jsr Tile
 cmp #1
 beq @surface
 cmp #$80
 jne @free
@surface:
 lda M_PROBE_Y
 clc
 adc N_VERTICAL_SCROLL
 bcs @wrap
 cmp #$F0
 bcc @row
@wrap:
 adc #$0F
@row:
 and #$F0
 sec
 sbc N_VERTICAL_SCROLL
 bcs :+
 clc
 adc #$F0
:
 sec
 sbc #12
 jcc @free
 sta M_TMP
 lda N_SPRITE_Y_POS+P
 sec
 sbc M_TMP
 cmp #17
 bcs @blocked
 lda N_SPRITE_Y_POS+P
 sta M_PROBE_Y
 lda M_TMP
 sta N_SPRITE_Y_POS+P
 jsr Side
 bcs @restore
 lda M_SIGN
 eor #$FE
 sta M_SIGN
 jsr Side
 php
 lda M_SIGN
 eor #$FE
 sta M_SIGN
 plp
 bcs @restore
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 sta M_SWIMMING
 sta M_SWIM_TIMER
 lda #1
 sta M_AREA_TYPE
 lda #$70
 sta M_FALL_FORCE
@free:
 clc
 rts
@restore:
 lda M_PROBE_Y
 sta N_SPRITE_Y_POS+P
@blocked:
 sec
 rts
Side:
 lda N_PLAYER_HIDDEN+P
 bne @free
 lda N_LEVEL_LOCATION_TYPE
 bne @free
 lda #7
 ldx M_SIGN
 bpl :+
 lda #$F8
:
 clc
 adc N_SPRITE_X_POS+P
 sta M_TILE
 tay
 lda N_SPRITE_Y_POS+P
 clc
 adc #11
 jsr Tile
 bmi @solid
 ldy M_TILE
 lda N_SPRITE_Y_POS+P
 sec
 sbc #3
 bcc @free
 jsr Tile
 bmi @solid
 lda M_TALL
 beq @free
 ldy M_TILE
 lda N_SPRITE_Y_POS+P
 sec
 sbc #19
 bcc @free
 jsr Tile
 bmi @solid
@free: clc
 rts
@solid: sec
 rts
MoveY:
 lda M_STATE
 jeq @done
 lda M_VY
 bpl @gravityType
 lda M_HELD
 and #$80
 and M_PREV
 bne @integrate
 lda M_JUMP_ORIGIN
 sec
 sbc N_SPRITE_Y_POS+P
 cmp #1
 bcc @integrate
@gravityType:
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
 lda N_SPRITE_Y_POS+P
 clc
 adc M_SIGN
 sta N_SPRITE_Y_POS+P
 php
 lda M_SIGN
 bmi @negativeStep
 plp
 bcc @moved
 inc N_PLAYER_HIDDEN+P
 jmp @moved
@negativeStep:
 plp
 bcs @moved
 dec N_PLAYER_HIDDEN+P
@moved:
 lda N_PLAYER_HIDDEN+P
 jne @next
 lda M_SIGN
 bmi @up
 lda N_LEVEL_LOCATION_TYPE
 bne @probeFloor
 lda N_SPRITE_Y_POS+P
 clc
 adc #12
 adc N_VERTICAL_SCROLL
 and #$0F
 bne @next
@probeFloor:
 jsr Feet
 beq @next
 cmp #2
 beq @next
@land:
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 rts
@up:
 lda N_LEVEL_LOCATION_TYPE
 bne @next
 lda #3
 ldx M_TALL
 beq :+
 lda #19
:
 sta M_TMP
 lda N_SPRITE_Y_POS+P
 sec
 sbc M_TMP
 bcc @next
 sta M_PROBE_Y
 lda N_SPRITE_X_POS+P
 sec
 sbc #7
 tay
 lda M_PROBE_Y
 jsr Tile
 bmi @ceiling
 lda N_SPRITE_X_POS+P
 clc
 adc #6
 tay
 lda M_PROBE_Y
 jsr Tile
 bpl @next
@ceiling:
 inc N_SPRITE_Y_POS+P
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 sta M_Y_FRAC
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
 bmi @scroll
 cmp #4
 bcc @scroll
 lda M_VY_FRAC
 cmp #$80
 bcc @scroll
 lda #4
 sta M_VY
 lda #0
 sta M_VY_FRAC
@scroll:
 lda M_SWIMMING
 beq @camera
 lda N_SPRITE_Y_POS+P
 cmp M_WATER_LEVEL
 bcc @done
 lda M_WATER_LEVEL
 sta N_SPRITE_Y_POS+P
 lda #0
 sta M_VY
 sta M_VY_FRAC
 sta M_Y_FRAC
 rts
@camera:
 lda N_LEVEL_SCROLLING_TYPE
 beq @done
 lda M_VY
 bpl @done
 lda N_SPRITE_Y_POS+P
 cmp #$50
 bcs @done
 ldx #P
 jsr N_set_boss_auto_scroll
 beq @done
 lda #$50
 sec
 sbc N_SPRITE_Y_POS+P
 cmp N_FRAME_SCROLL
 bcc @smallerScroll
 pha
 sec
 sbc N_FRAME_SCROLL
 ldx N_PLAYER_FRAME_SCROLL+(1-P)
 beq :+
 clc
 adc N_SPRITE_Y_POS+(1-P)
 sta N_SPRITE_Y_POS+(1-P)
:
 pla
 sta N_FRAME_SCROLL
 lda #$50
 bne @cameraY
@smallerScroll:
 sta M_TMP
 lda N_FRAME_SCROLL
 sec
 sbc M_TMP
 clc
 adc #$50
@cameraY:
 sta N_SPRITE_Y_POS+P
 lda #1
 sta N_PLAYER_FRAME_SCROLL+P
@done: rts
Render:
 lda M_MAGIC
 cmp #$4D
 beq :+
 jsr Init
:
 ; Move owns the collision height and recomputes it before probing.
 ; Sprite selection only needs power/crouch, so avoid another Body call.
 jsr SelectFrame
 tax
 lda M_POWER_FREEZE
 bne @ready
 lda N_PLAYER_RECOIL_TIMER+P
 cmp #12
 bcc @ready
 lda RifleTile,x
 cmp #$FF
 beq @ready
 txa
 ora #$40
 bne @key
@ready:
 txa
@key:
 ldx N_LEVEL_LOCATION_TYPE
 cpx #1
 bne :+
 ora #$80
:
 sta M_FRAME
 cmp M_LAST_FRAME
 jeq @done
 eor M_LAST_FRAME
 and #$BF
 jeq @toggleRecoil
 lda M_FRAME
 sta M_LAST_FRAME
 and #$3F
 lsr
 pha
 lda #0
 ror
 sta $00
 pla
 clc
 bit M_FRAME
 bmi @backPointer
 adc #>MarioFrames
 jmp @pointerReady
@backPointer:
 adc #$69
@pointerReady:
 sta $01
 ldy #0
@copy:
 .repeat 16
 lda ($00),y
 sta $6200+P*$80,y
 iny
 .endrepeat
 bpl @copy
 lda M_FRAME
 and #$40
 beq @done
@toggleRecoil:
 lda M_FRAME
 sta M_LAST_FRAME
 bmi @done
 and #$3F
 tax
 lda RecoilPatchLo,x
 sta $00
 lda RecoilPatchHi,x
 sta $01
 ldy #0
@patch:
 lda ($00),y
 bmi @done
 tax
 iny
 lda ($00),y
 eor $6200+P*$80,x
 sta $6200+P*$80,x
 iny
 bne @patch
@done:
 lda N_CPU_SPRITE_BUFFER+P
 cmp #$91
 beq :+
 lda #0
 sta N_CPU_SPRITE_BUFFER+P
:
 lda #1
 ldx M_CROUCH
 beq :+
 lda #$17
:
 sta N_PLAYER_SPRITE_CODE+P
 ldx #P
 rts
SelectFrame:
 lda N_PLAYER_STATE+P
 cmp #2
 bne @alive
 lda #22
 rts
@alive:
 cmp #3
 bne :+
 lda #24
 ldx M_POWER
 bne @standing
 lda #23
@standing:
 rts
:
 lda M_POWER_FREEZE
 beq @normal
 jmp MorphFrame
@normal:
 lda N_INDOOR_PLAYER_ADV_FLAG+P
 jne @walk
 lda N_BOSS_DEFEATED_FLAG
 bpl :+
 lda N_PLAYER_JUMP_STATUS+P
 jeq @walk
 jmp @jump
:
 lda N_INDOOR_PLAYER_JUMP_FLAG+P
 beq @environment
 lda #4
 ldx M_POWER
 bne :+
 lda #16
:
 rts
@environment:
 lda M_SWIMMING
 beq @size
 jsr Animate
 clc
 adc #5
 ldx M_POWER
 bne :+
 clc
 adc #12
:
 rts
@size:
 lda M_POWER
 beq @small
 lda M_CROUCH
 beq :+
 lda #10
 rts
:
 lda M_THROW
 beq :+
 lda #11
 rts
:
 lda M_STATE
 bne @jump
 lda M_SMB_X_SPEED
 beq :+
 lda M_INPUT_DIR
 beq @walk
 cmp M_MOVING_DIR
 beq @walk
 lda #3
 rts
:
 lda #24
 rts
@small:
 lda M_STATE
 beq :+
 lda #16
 rts
:
 lda M_HELD
 and #$0F
 cmp #4
 bne :+
 lda #26
 rts
:
 lda M_SMB_X_SPEED
 beq :+
 lda M_INPUT_DIR
 beq @walk
 cmp M_MOVING_DIR
 beq @walk
 lda #15
 rts
:
 lda #23
 rts
@jump:
 lda #4
 ldx M_POWER
 bne @jumpReady
 lda #16
@jumpReady:
 rts
@walk:
 jsr Animate
 ldx M_POWER
 bne :+
 clc
 adc #12
:
 rts
Animate:
 lda M_ANIM_TIMER
 beq @step
 dec M_ANIM_TIMER
 lda M_ANIM
 rts
@step:
 lda M_ANIM_SET
 sta M_ANIM_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc :+
 lda #0
 sta M_ANIM
:
 rts
.include "morph.inc"
.include "smb-land.inc"

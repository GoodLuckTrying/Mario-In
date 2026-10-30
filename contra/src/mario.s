.setcpu "6502"
.macpack longbranch
.include "native.inc"
.include "globals.inc"
.import __VBLANK_LOAD__
.export Boot, MoveGate, RenderGate, DrawGate, DmaGate, AssetsGate
.export FireGate, BulletGate, DamageGate, PickupGate, CollisionGate, ResetGate
.export PaletteGate, ScrollGate
.export BridgeTileGate
.export PauseGate
.export DemoEndGate, SessionGate
.export TitleInit,TitleGate,TitleTheme,TitleOne,TitleThree,TitleFour,TitleRaster,TitleDraw,TitleScroll
.export TitleBlinkLo,TitleBlinkHi,TitleAnimate,TitleBlinkGate
.export EnemyGate
.export PlayerBoxGate
.export SolidGate, OamStartGate, OamAdvanceGate
.export P0Move, P1Move, Compose, Stomps, Fireballs, Damage, Collect
.export P0Tile, P1Tile
.export MakeGun, P0Render, P1Render
.export FireEnemies
.segment "CODE"
.byte 8
.scope P0
 BASE=$6000
 P=0
 .include "engine.inc"
.endscope
.scope P1
 BASE=$6080
 P=1
 .include "engine.inc"
.endscope
P0Move=P0::Move
P1Move=P1::Move
P0Tile=P0::Tile
P1Tile=P1::Tile
P0Render=P0::Render
P1Render=P1::Render
Move:
 lda G_PLAYER
 bne :+
 jmp P0::Move
:
 jmp P1::Move
Render:
 lda G_PLAYER
 bne :+
 jmp P0::Render
:
 jmp P1::Render
SyncNative:
 lda G_PLAYER
 bne :+
 jmp P0::SyncNative
:
 jmp P1::SyncNative
PlayerOffset:
 lda G_PLAYER
 lsr
 ror
 tax
 rts
WeaponFacing:
 ; Native aiming can turn while SMB's grounded Down+direction filter
 ; suppresses movement. Keep the visible body and both weapons facing
 ; the same way without changing the movement core's facing state.
 ldx G_PLAYER
 lda N_PLAYER_AIM_DIR,x
 cmp #10
 bcc @native
 jsr PlayerOffset
 lda $600B,x
 cmp #2
 rts
@native:
 cmp #5
 rts
Damage:
 jsr PlayerOffset
 lda $6049,x
 bne @protect
 lda $6004,x
 beq @dead
 lda #0
 sta $6004,x
 sta $601D,x
 lda #32
 sta $6035,x
 lda #1
 sta $6046,x
 ldx G_PLAYER
 lda #96
 sta N_NEW_LIFE_INVINCIBILITY_TIMER,x
@protect:
 lda #1
 rts
@dead:
 lda #0
 rts
Collect:
 jsr PlayerOffset
 lda $6004,x
 cmp #2
 bcs @done
 inc $6004,x
 lda #0
 ldy $6004,x
 cpy #2
 bne :+
 lda #2
:
 sta $6046,x
 lda #40
 sta $6035,x
@done:
 ldx G_PLAYER
 lda #$1F
 jsr N_play_sound
 rts
Supplies:
 jsr PlayerOffset
 lda $6004,x
 cmp #2
 bcc :+
 lda #2
 sta $604C,x
 rts
:
 lda $604C,x
 cmp #2
 bcs @done
 lda $6005,x
 ora $6035,x
 bne @done
 ldy G_PLAYER
 lda N_PLAYER_STATE,y
 cmp #1
 bne @done
 lda N_SPRITE_Y_POS,y
 sta G_Y
 lda N_SPRITE_X_POS,y
 sta G_X
 lda $604C,x
 beq :+
 lda #24
:
 clc
 adc #24
 ldy G_PLAYER
 beq :+
 clc
 adc #56
:
 clc
 adc G_X
 bcs @clamp
 cmp #$D8
 bcc @x
@clamp: lda #$D8
@x: sta G_X
 ldx #15
@slot:
 lda N_ENEMY_ROUTINE,x
 beq @spawn
 dex
 bpl @slot
 rts
@spawn:
 lda #0
 sta N_ENEMY_TYPE,x
 jsr N_initialize_enemy
 lda G_X
 sta N_ENEMY_X_POS,x
 lda G_Y
 clc
 adc #6
 sta N_ENEMY_Y_POS,x
 lda #3
 sta N_ENEMY_ROUTINE,x
 lda #$80
 sta N_ENEMY_STATE_WIDTH,x
 sta N_ENEMY_ATTRIBUTES,x
 jsr PlayerOffset
 inc $604C,x
@done: rts
CanFire:
 jsr PlayerOffset
 lda $6004,x
 cmp #2
 bne @no
 lda $6035,x
 bne @no
 ldx G_PLAYER
 lda N_PLAYER_HIDDEN,x
 bne @no
 lda N_CONTROLLER_STATE_DIFF,x
 and #$40
 rts
@no: lda #0
 rts
SpawnFire:
 jsr CanFire
 beq @done
 ldx G_PLAYER
 lda N_PLAYER_STATE,x
 cmp #1
 bne @done
 lda G_PLAYER
 tax
 lda G_FIRE_ACTIVE,x
 beq @slot
 inx
 inx
 lda G_FIRE_ACTIVE,x
 bne @done
@slot:
 lda #1
 sta G_FIRE_ACTIVE,x
 lda #0
 sta G_FIRE_WALL,x
 sta G_FIRE_FORCE,x
 sta G_FIRE_POS,x
 lda #4
 sta G_FIRE_VY,x
 lda #100
 sta G_FIRE_LIFE,x
 ldy G_PLAYER
 tya
 sta G_FIRE_OWNER,x
 lda N_SPRITE_X_POS,y
 sta G_FIRE_X,x
 lda N_SPRITE_Y_POS,y
 sec
 sbc #4
 sta G_FIRE_Y,x
 stx G_SLOT
 jsr PlayerOffset
 lda #8
 sta $602D,x
 jsr WeaponFacing
 lda #4
 bcc :+
 lda #$FC
:
 ldx G_SLOT
 sta G_FIRE_VX,x
 lda N_LEVEL_LOCATION_TYPE
 and #1
 beq @sound
 jsr IndoorFire
@sound:
 lda #$0A
 jsr N_play_sound
@done:
 rts
IndoorFire:
 ; Match the base hallway's 42-frame perspective trip, with its separate
 ; low shot plane for crouching targets. Guns retain their native routines.
 lda #2
 sta G_FIRE_ACTIVE,x
 lda #42
 sta G_FIRE_LIFE,x
 lda #0
 sta G_FIRE_POS,x
 ldy G_PLAYER
 lda N_SPRITE_X_POS,y
 sta G_FIRE_X,x
 lda N_SPRITE_Y_POS,y
 sec
 sbc #24
 sta G_FIRE_Y,x
 lda N_PLAYER_JUMP_STATUS,y
 beq @ground
 lda N_SPRITE_Y_POS,y
 cmp #$98
 bcc :+
 lda #$98
:
 sta G_FIRE_Y,x
 jmp @velocity
@ground:
 lda N_PLAYER_AIM_DIR,y
 cmp #4
 beq @low
 cmp #5
 bne @velocity
@low:
 inc G_FIRE_ACTIVE,x
 lda N_SPRITE_Y_POS,y
 sec
 sbc #12
 sta G_FIRE_Y,x
@velocity:
 lda #128
 sec
 sbc G_FIRE_X,x
 sta G_TMP
 asl
 asl
 sta G_FIRE_FORCE,x
 lda G_TMP
 .repeat 6
  cmp #$80
  ror
 .endrepeat
 sta G_FIRE_VX,x
 rts
Fireballs:
 ldx #3
@loop:
 stx G_SLOT
 lda G_FIRE_ACTIVE,x
 jeq @next
 lda G_FIRE_WALL,x
 jne @remove
 dec G_FIRE_LIFE,x
 jeq @remove
 lda G_FIRE_ACTIVE,x
 cmp #2
 jcs @indoor
 lda N_LEVEL_SCROLLING_TYPE
 bne @vertical
 lda G_FIRE_X,x
 sec
 sbc N_FRAME_SCROLL
 sta G_FIRE_X,x
 lda G_FIRE_Y,x
 clc
 adc #4
 tay
 lda G_FIRE_X,x
 jsr N_get_bg_collision
 ldx G_SLOT
 cmp #$80
 bne @x
 jsr WallImpact
 jmp @x
@vertical:
 lda G_FIRE_Y,x
 clc
 adc N_FRAME_SCROLL
 sta G_FIRE_Y,x
@x:
 lda G_FIRE_X,x
 clc
 adc G_FIRE_VX,x
 cmp #8
 jcc @remove
 cmp #$F8
 jcs @remove
 sta G_FIRE_X,x
 lda G_FIRE_POS,x
 clc
 adc G_FIRE_FORCE,x
 sta G_FIRE_POS,x
 lda G_FIRE_VY,x
 adc G_FIRE_Y,x
 sta G_FIRE_Y,x
 cmp #$E8
 jcs @remove
 lda G_FIRE_FORCE,x
 clc
 adc #$80
 sta G_FIRE_FORCE,x
 lda G_FIRE_VY,x
 adc #0
 bmi :+
 cmp #4
 bcc :+
 lda #3
:
 sta G_FIRE_VY,x
 bpl @feet
 ldy G_FIRE_Y,x
 lda G_FIRE_X,x
 jsr N_get_bg_collision
 ldx G_SLOT
 cmp #$80
 bne @draw
 jsr WallImpact
 jmp @draw
@feet:
 lda G_FIRE_Y,x
 clc
 adc #8
 tay
 lda G_FIRE_X,x
 jsr N_get_bg_collision
 ldx G_SLOT
 cmp #0
 beq @draw
 cmp #2
 beq @draw
 lda #$FD
 sta G_FIRE_VY,x
 lda #0
 sta G_FIRE_FORCE,x
 sta G_FIRE_POS,x
 lda G_FIRE_Y,x
 clc
 adc N_VERTICAL_SCROLL
 and #$F8
 sec
 sbc N_VERTICAL_SCROLL
 sta G_FIRE_Y,x
@draw:
 jmp @next
@indoor:
 lda G_FIRE_POS,x
 clc
 adc G_FIRE_FORCE,x
 sta G_FIRE_POS,x
 lda G_FIRE_X,x
 adc G_FIRE_VX,x
 sta G_FIRE_X,x
 dec G_FIRE_Y,x
 jmp @next
@remove:
 lda #0
 sta G_FIRE_ACTIVE,x
@next:
 ldx G_SLOT
 dex
 jpl @loop
 rts
WallImpact:
 ; A native background target can sit behind the solid tile it draws.
 ; Let a nearby shot reach that target's actual hitbox, including the
 ; rear Jungle cannon, while ordinary walls still consume fireballs.
 lda #1
 sta G_RESULT
 lda N_ENEMY_CURRENT_SLOT
 pha
 ldx #15
@enemy:
 lda N_ENEMY_ROUTINE,x
 beq @next
 lda N_ENEMY_STATE_WIDTH,x
 bmi @next
 lda N_ENEMY_SPRITES,x
 cmp #1
 bne @next
 lda N_ENEMY_HP,x
 beq @next
 cmp #$F0
 bcs @next
 ldy G_SLOT
 lda G_FIRE_VX,y
 bmi @left
 lda N_ENEMY_X_POS,x
 sec
 sbc G_FIRE_X,y
 bcc @next
 bcs @distance
@left:
 lda G_FIRE_X,y
 sec
 sbc N_ENEMY_X_POS,x
 bcc @next
@distance:
 cmp #41
 bcs @next
 stx N_ENEMY_CURRENT_SLOT
 ldy #4
 jsr N_set_enemy_collision_box
 lda $08
 sec
 sbc #4
 sta $08
 lda $0A
 clc
 adc #8
 sta $0A
 ldy G_SLOT
 lda G_FIRE_Y,y
 sec
 sbc $08
 cmp $0A
 bcs @next
 lda #0
 sta G_RESULT
 beq @done
@next:
 dex
 bpl @enemy
@done:
 pla
 sta N_ENEMY_CURRENT_SLOT
 ldx G_SLOT
 lda G_RESULT
 sta G_FIRE_WALL,x
 rts
FireEnemies:
 ; Cache the actor's expanded box once for this volley. Empty slots and
 ; missed shots do not change it; a damaging hit may change native state.
 ldx N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_STATE_WIDTH,x
 jmi @done
 lda N_ENEMY_HP,x
 jeq @done
 cmp #$F0
 jcs @done
 lda G_FIRE_ACTIVE
 ora G_FIRE_ACTIVE+1
 ora G_FIRE_ACTIVE+2
 ora G_FIRE_ACTIVE+3
 jeq @done
 jsr FireEnemyBox
 ldx #3
 stx G_FIRE_ITER
@loop:
 ldx G_FIRE_ITER
 lda G_FIRE_ACTIVE,x
 jeq @next
 cmp #2
 bcc @box
 ldy N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_STATE_WIDTH,y
 and #$20
 beq @depth
 lda G_FIRE_ACTIVE,x
 cmp #3
 bne @next
 beq @box
@depth:
 lda G_FIRE_LIFE,x
 cmp #2
 bcs @next
@box:
 lda G_FIRE_Y,x
 sec
 sbc $08
 cmp $0A
 bcs @next
 lda G_FIRE_X,x
 sec
 sbc $09
 cmp $0B
 bcs @next
 lda #0
 sta G_FIRE_ACTIVE,x
 lda G_FIRE_OWNER,x
 jsr N_bullet_collision_logic
 ldx N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_STATE_WIDTH,x
 bmi @done
 lda N_ENEMY_HP,x
 beq @done
 cmp #$F0
 bcs @done
 ; Native damage can overwrite the box scratch or change the actor shape.
 jsr FireEnemyBox
@next:
 dec G_FIRE_ITER
 jpl @loop
@done:
 ldx N_ENEMY_CURRENT_SLOT
 rts
FireEnemyBox:
 ldx N_ENEMY_CURRENT_SLOT
 ldy #4
 jsr N_set_enemy_collision_box
 ; Match the existing two-pixel tolerance, four for background weak points.
 lda #2
 sta G_TMP
 ldx N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_SPRITES,x
 cmp #1
 bne :+
 inc G_TMP
 inc G_TMP
:
 lda $08
 sec
 sbc G_TMP
 sta $08
 lda $09
 sec
 sbc G_TMP
 sta $09
 asl G_TMP
 lda $0A
 clc
 adc G_TMP
 sta $0A
 lda $0B
 clc
 adc G_TMP
 sta $0B
 rts
Stomps:
 ; Perspective-room actors at the back wall are not on Mario's floor
 ; plane. A jump must not bounce off them or skip their destruction logic.
 lda N_LEVEL_LOCATION_TYPE
 and #1
 jne @done
 ldx G_SLOT
 lda N_ENEMY_TYPE,x
 cmp #32
 jcs @done
 sta G_TMP
 lda N_CURRENT_LEVEL
 asl
 asl
 asl
 asl
 asl
 ora G_TMP
 tay
 lda Stompable,y
 jeq @done
 sta G_STOMP_KIND
 lda N_ENEMY_HP,x
 jeq @done
 cmp #$F0
 jcs @done
 ; Derive the landing surface from the real actor shape, not a fixed
 ; 32-pixel soldier box (which put bosses' mouths below Mario's feet).
 ldy #4
 jsr N_set_enemy_collision_box
 lda $08
 clc
 adc #2
 sta G_STOMP_TOP
 lda $09
 sec
 sbc #5
 sta G_STOMP_LEFT
 lda $0B
 clc
 adc #10
 sta G_STOMP_WIDTH
 lda #1
 sta G_PLAYER
@player:
 ldy G_PLAYER
 lda N_PLAYER_HIDDEN,y
 jne @next
 lda N_PLAYER_STATE,y
 cmp #1
 jne @next
 jsr PlayerOffset
 lda $6005,x
 jeq @next
 lda $6018,x
 bpl @descending
 lda $604A,x
 jeq @next
@descending:
 lda G_STOMP_TOP
 sta G_TMP
 lda $602F,x
 clc
 adc #12
 sec
 sbc G_TMP
 cmp #9
 bcc @current
 cmp #$E0
 jcc @next
@current:
 ldy G_PLAYER
 lda N_SPRITE_Y_POS,y
 clc
 adc #12
 sec
 sbc G_TMP
 cmp #16
 bcc @overlap
 cmp #$FE
 jcc @next
@overlap:
 ldy G_PLAYER
 lda N_SPRITE_X_POS,y
 sec
 sbc G_STOMP_LEFT
 cmp G_STOMP_WIDTH
 bcs @next
 lda #$FC
 sta $6018,x
 lda #0
 sta $6019,x
 sta $6017,x
 lda #1
 sta $6005,x
 sta $604A,x
 lda #16
 sta $6049,x
 lda G_PLAYER
 sta $17
 ldx G_SLOT
 lda G_STOMP_KIND
 cmp #2
 bne @kill
 lda N_ENEMY_HP,x
 cmp #3
 bcc @kill
 sec
 sbc #2
 sta N_ENEMY_HP,x
 jmp @done
@kill:
 lda #0
 sta N_ENEMY_HP,x
 jsr N_add_enemy_score_set_enemy_routine
 jmp @done
@next:
 dec G_PLAYER
 jpl @player
@done: rts
Prepare:
 lda #0
 .repeat 4,I
  sta G_FIRE_ACTIVE+I
 .endrepeat
 jsr P0::Render
 jsr P1::Render
 lda #0
 sta G_PENDING
 lda #$FF
 sta G_PPU0
 sta G_PPU1
 lda N_PPUCTRL_SETTINGS
 and #$7B
 sta $2000
 bit $2002
 lda #2
 sta $2006
 lda #$80
 sta $2006
 ldx #0
@poses:
 lda $6200,x
 sta $2007
 inx
 bne @poses
 lda $601F
 sta G_PPU0
 lda $609F
 sta G_PPU1
 bit $2002
 lda #3
 sta $2006
 lda #$80
 sta $2006
 ldx #0
@items:
 lda ItemChr,x
 sta $2007
 inx
 cpx #128
 bne @items
 lda #4
 sta $2006
 lda #0
 sta $2006
 ldx #0
@fire:
 lda FireChr,x
 sta $2007
 inx
 cpx #32
 bne @fire
 ; These tiles belonged exclusively to the retired native player art.
 ; Load once during forced blank, leaving the frame upload at 128 bytes.
 lda #6
 sta $2006
 lda #$80
 sta $2006
 ldx #0
@rifles:
 lda RifleChr,x
 sta $2007
 inx
 bne @rifles
@rifleTail:
 lda RifleChr+256,x
 sta $2007
 inx
 cpx #128
 bne @rifleTail
 rts
Items:
 ldx #15
@item:
 lda N_ENEMY_ROUTINE,x
 beq @next
 lda N_ENEMY_TYPE,x
 bne @next
 lda N_ENEMY_ATTRIBUTES,x
 bpl @next
 jsr ItemPower
 beq :+
 lda #$65
 bne @set
:
 lda #$4F
@set:
 sta N_ENEMY_SPRITES,x
 lda #0
 sta N_ENEMY_SPRITE_ATTR,x
@next:
 dex
 bpl @item
 rts
ItemPower:
 lda N_P1_GAME_OVER_STATUS
 bne @p1
 lda N_P1_GAME_OVER_STATUS+1
 bne @p0
 lda N_ENEMY_X_POS,x
 sec
 sbc N_SPRITE_X_POS
 bpl :+
 eor #$FF
 clc
 adc #1
:
 sta G_TMP
 lda N_ENEMY_X_POS,x
 sec
 sbc N_SPRITE_X_POS+1
 bpl :+
 eor #$FF
 clc
 adc #1
:
 cmp G_TMP
 bcs @p0
@p1: lda $6084
 rts
@p0: lda $6004
 rts
Compose:
 lda #1
 sta G_CHR_LOCK
 jsr P0::Render
 jsr P1::Render
 .repeat 2,P
  ldy #0+P*6
  lda $6004+P*$80
  cmp #2
  bcc :+
  ldy #3+P*6
:
  .repeat 3,I
   lda PaletteColors+I,y
   sta N_PALETTE_CPU_BUFFER+17+P*8+I
  .endrepeat
 .endrepeat
 ldx #0
 stx G_PLAYER
@player:
 lda G_PLAYER
 asl
 asl
 asl
 asl
 tax
 lda #$F8
 sta G_BODY_OAM,x
 sta G_BODY_OAM+4,x
 sta G_BODY_OAM+8,x
 sta G_BODY_OAM+12,x
 ldy G_PLAYER
 lda N_P1_GAME_OVER_STATUS,y
 jne @nextPlayer
 lda N_PLAYER_HIDDEN,y
 jne @nextPlayer
 lda N_PLAYER_STATE,y
 jeq @nextPlayer
 lda N_NEW_LIFE_INVINCIBILITY_TIMER,y
 beq @visible
 lda N_FRAME_COUNTER
 and #4
 jne @nextPlayer
@visible:
 lda N_SPRITE_Y_POS,y
 sec
 sbc #20
 sta G_BODY_OAM,x
 sta G_BODY_OAM+4,x
 clc
 adc #16
 sta G_BODY_OAM+8,x
 sta G_BODY_OAM+12,x
 lda G_PLAYER
 asl
 asl
 asl
 clc
 adc #$28
 sta G_BODY_OAM+1,x
 clc
 adc #2
 sta G_BODY_OAM+5,x
 clc
 adc #2
 sta G_BODY_OAM+9,x
 clc
 adc #2
 sta G_BODY_OAM+13,x
 stx G_END
 jsr WeaponFacing
 lda #0
 bcc :+
 lda #$40
:
 sta G_TMP
 lda G_PLAYER
 asl
 ora G_TMP
 ldy G_PLAYER
 pha
 lda N_PLAYER_BG_FLAG_EDGE_DETECT,y
 and #$80
 beq :+
 pla
 ora #$20
 pha
:
 pla
 ldx G_END
 sta G_BODY_OAM+2,x
 sta G_BODY_OAM+6,x
 sta G_BODY_OAM+10,x
 sta G_BODY_OAM+14,x
 ldy G_PLAYER
 lda N_SPRITE_X_POS,y
 ldy G_TMP
 beq @right
 sta G_BODY_OAM+3,x
 sta G_BODY_OAM+11,x
 sec
 sbc #8
 sta G_BODY_OAM+7,x
 sta G_BODY_OAM+15,x
 jmp @nextPlayer
@right:
 sta G_BODY_OAM+7,x
 sta G_BODY_OAM+15,x
 sec
 sbc #8
 sta G_BODY_OAM+3,x
 sta G_BODY_OAM+11,x
@nextPlayer:
 inc G_PLAYER
 lda G_PLAYER
 cmp #2
 jcc @player
 lda #32
 ; Native palette cycling waits while NUM_PALETTES_TO_LOAD is pending.
 ; Do not keep that byte busy with our every-frame sprite palette update.
 sta G_PALETTE_DIRTY
 ldx #48
 ldy #0
@fire:
 lda G_FIRE_ACTIVE,y
 beq @nextFire
 lda G_FIRE_Y,y
 sec
 sbc #4
 sta G_FINAL_OAM,x
 lda #$40
 sta G_FINAL_OAM+1,x
 lda G_FIRE_OWNER,y
 sta G_FINAL_OAM+2,x
 lda G_FIRE_X,y
 sec
 sbc #4
 sta G_FINAL_OAM+3,x
 inx
 inx
 inx
 inx
@nextFire:
 iny
 cpy #4
 bne @fire
 ; Rifles occupy slots 0..3, complete bodies 4..11, fireballs 12..15.
 ; Gun priority keeps the restored torso from covering the rifle.
 cpx #64
 bcs @full
 lda #$F8
@hide:
 sta G_FINAL_OAM,x
 inx
 inx
 inx
 inx
 cpx #64
 bcc @hide
@full:
 lda #$64
 sta G_DMA
 ; A terrain transfer may delay this queue for several frames. Keep its
 ; contents current, and let a landed player leave a displayed jump pose
 ; before spending the next free transfer on the other player's walk cycle.
 .repeat 2,P
  ldx #P
  lda G_PPU0+P
  jsr MakeGun
  .repeat 8,I
   lda G_GUN_STAGE+I
   sta G_FINAL_OAM+P*8+I
  .endrepeat
 .endrepeat
 jsr QueueLatest
 lda G_PENDING
 beq @unlock
 ldx G_TARGET
 lda G_POSE
 jsr MakeGun
 .repeat 8,I
  lda G_GUN_STAGE+I
  sta G_GUN_UPLOAD+I
 .endrepeat
@unlock:
 lda #0
 sta G_CHR_LOCK
 rts

MakeGun:
 ; Parameter A is the displayed (or pending) pose key, X is the player.
 ; Build a matching pair without changing the other player's OAM.
 stx G_GUN_PLAYER
 and #$7F
 tax
 lda #$F8
 sta G_GUN_STAGE
 sta G_GUN_STAGE+4
 lda G_GUN_PLAYER
 asl
 asl
 asl
 asl
 tay
 lda G_BODY_OAM,y
 cmp #$F8
 bne @pose
 lda G_BODY_OAM+8,y
 cmp #$F8
 jeq @done
@pose:
 cpx #64+MARIO_POSE_COUNT
 jcs @done
 lda RifleTile,x
 cmp #$FF
 jeq @done
 sta G_GUN_STAGE+1
 clc
 adc #2
 sta G_GUN_STAGE+5
 lda RifleX,x
 sta G_GUN_X
 lda G_BODY_OAM,y
 clc
 adc RifleY,x
 sta G_GUN_Y
 lda G_BODY_OAM+2,y
 and #$60
 ora #3
 sta G_GUN_STAGE+2
 sta G_GUN_STAGE+6
 ldx G_GUN_PLAYER
 lda N_LEVEL_LOCATION_TYPE
 cmp #1
 bne :+
 lda #3
 bne @angle
:
 lda N_PLAYER_AIM_DIR,x
 tax
 lda AimMode,x
 beq @place
 cmp #5
 bne @angle
 ; Down on the ground is Contra's crouched horizontal shot. In the
 ; air, the same native aim codes fire vertically down.
 ldx G_GUN_PLAYER
 lda N_PLAYER_JUMP_STATUS,x
 beq @place
 lda #4
@angle:
 sta G_GUN_ANGLE
 tax
 lda G_GUN_Y
 clc
 adc AimYAdjust,x
 sta G_GUN_Y
 lda G_GUN_STAGE+2
 ora AimFlip,x
 sta G_GUN_STAGE+2
 sta G_GUN_STAGE+6
 lda G_GUN_STAGE+1
 sec
 sbc #$68
 lsr
 lsr
 tax
 lda G_GUN_ANGLE
 cmp #3
 bcs @vertical
 lda G_GUN_X
 clc
 adc AngleDiagDX,x
 sta G_GUN_X
 lda AngleDiagTile,x
 sta G_GUN_STAGE+1
 clc
 adc #2
 sta G_GUN_STAGE+5
 jmp @place
@vertical:
 lda G_GUN_X
 clc
 adc AngleVerticalDX,x
 sta G_GUN_X
 lda AngleVerticalTile,x
 sta G_GUN_STAGE+1
 lda #$8E
 sta G_GUN_STAGE+5
@place:
 lda G_GUN_Y
 cmp #$EF
 bcs @done
 sta G_GUN_STAGE
 sta G_GUN_STAGE+4
 lda G_GUN_STAGE+2
 and #$40
 bne @left
 lda G_BODY_OAM+3,y
 clc
 adc G_GUN_X
 sta G_GUN_STAGE+3
 clc
 adc #8
 jmp @second
@left:
 lda G_BODY_OAM+3,y
 sec
 sbc G_GUN_X
 sta G_GUN_STAGE+3
 sec
 sbc #8
@second:
 sta G_GUN_STAGE+7
@done:
 rts

QueueLatest:
 ldx #0
 ldy #0
@landing:
 lda N_P1_GAME_OVER_STATUS,x
 bne @nextLanding
 lda N_PLAYER_HIDDEN,x
 bne @nextLanding
 lda N_PLAYER_STATE,x
 cmp #1
 bne @nextLanding
 lda $6005,y
 bne @nextLanding
 lda G_PPU0,x
 and #$3F
 cmp #4
 beq @landed
 cmp #16
 bne @nextLanding
@landed:
 lda $601F,y
 and #$3F
 cmp #4
 beq @nextLanding
 cmp #16
 beq @nextLanding
 lda $601F,y
 jmp @selected
@nextLanding:
 inx
 ldy #$80
 cpx #2
 bne @landing
 lda G_PENDING
 beq @fresh
 ldx G_TARGET
 beq @pending0
 lda $609F
 jmp @pendingPose
@pending0:
 lda $601F
@pendingPose:
 cmp G_PPU0,x
 bne @selected
 ; The player returned to the pose already on the PPU. Drop the obsolete
 ; request rather than upload the intermediate jump after it has ended.
 lda #0
 sta G_PENDING
@fresh:
 lda G_NEXT
 eor #1
 beq @p0
 lda $609F
 cmp G_PPU1
 bne @queue1
@p0:
 lda $601F
 cmp G_PPU0
 beq @p1
 ldx #0
 beq @selected
@p1:
 lda $609F
 cmp G_PPU1
 jeq @done
@queue1:
 ldx #1
@selected:
 ldy G_PENDING
 beq @replace
 cpx G_TARGET
 bne @replace
 cmp G_POSE
 jeq @done
@replace:
 pha
 lda #0
 sta G_PENDING
 stx G_TARGET
 stx G_NEXT
 pla
 sta G_POSE
 ; Compose holds G_CHR_LOCK until both player buffers and the pending
 ; gun are complete. NMI can read the selected player buffer directly;
 ; a second 128-byte RAM copy is unnecessary.
 lda #1
 sta G_PENDING
@done: rts
PaletteColors: .byte $16,$27,$18,$37,$27,$16,$30,$27,$19,$37,$27,$19

CheatInput:
 lda N_DEMO_MODE
 bne @reset
 lda N_PAUSE_STATE
 bne @paused
 lda G_CHEAT_ARMED
 beq @reset
 lda #0
 sta G_CHEAT_ARMED
 lda #1
 sta G_INVINCIBLE
 lda #$20
 jsr N_play_sound
@reset:
 lda #0
 sta G_CHEAT_SEQUENCE
 sta G_CHEAT_SEQUENCE+1
 rts
@paused:
 ldx #0
@player:
 lda N_CONTROLLER_STATE,x
 and #$0F
 cmp #8
 bne @wrong
 lda N_CONTROLLER_STATE_DIFF,x
 and #$C0
 beq @next
 ldy G_CHEAT_SEQUENCE,x
 cmp CheatButtons,y
 bne @wrong
 inc G_CHEAT_SEQUENCE,x
 iny
 cpy #4
 bne @next
 lda #1
 sta G_CHEAT_ARMED
@wrong:
 lda #0
 sta G_CHEAT_SEQUENCE,x
@next:
 inx
 cpx #2
 bne @player
 rts
CheatButtons: .byte $40,$80,$80,$40

.segment "VBLANK"
UploadDma:
 lda G_MAGIC
 cmp #$4D
 jne @dma
 lda G_CHR_LOCK
 jne @dma
 lda G_PENDING
 jeq @dma
 lda N_CPU_GRAPHICS_BUFFER
 jne @dma
 lda N_PPUCTRL_SETTINGS
 and #$7B
 sta $2000
 bit $2002
 lda G_TARGET
 bne @second
 lda #2
 sta $2006
 lda #$80
 bne @addr
@second:
 lda #3
 sta $2006
 lda #0
@addr:
 sta $2006
 lda G_TARGET
 lsr
 ror
 tax
 .repeat 128,I
  lda $6200+I,x
  sta $2007
 .endrepeat
 ldx G_TARGET
 lda G_POSE
 sta G_PPU0,x
 txa
 asl
 asl
 asl
 tax
 .repeat 8,I
  lda G_GUN_UPLOAD+I
  sta G_FINAL_OAM+I,x
 .endrepeat
 lda #0
 sta G_PENDING
@dma:
 lda #0
 sta $2003
 lda G_DMA
 bne :+
 lda #2
:
 sta $4014
 rts

.segment "FIXED"
Boot:
 lda N_BANK_NUMBER
 pha
 ldy #8
 jsr N_set_rom_bank_to_y
 ldx #0
@copy:
 lda __VBLANK_LOAD__,x
 sta $6500,x
 lda __VBLANK_LOAD__+$100,x
 sta $6600,x
 lda __VBLANK_LOAD__+$200,x
 sta $6700,x
 lda __VBLANK_LOAD__+$300,x
 sta $6800,x
 lda #0
 sta $6000,x
 sta $6100,x
 sta $6200,x
 sta $6300,x
 lda #$F8
 sta $6400,x
 inx
 bne @copy
 lda #$4D
 sta G_MAGIC
 lda #0
 sta G_TITLE_ACTIVE
 lda #$64
 sta G_DMA
 pla
 tay
 jsr N_set_rom_bank_to_y
 lda #$0F
 sta $4015
 jmp N_init_APU+5
Enter:
 lda N_BANK_NUMBER
 pha
 ldy #8
 jsr N_set_rom_bank_to_y
 pla
 sta G_BANK
 rts
Leave:
 lda G_BANK
 tay
 jmp N_set_rom_bank_to_y
MoveGate:
 stx G_PLAYER
 lda N_BOSS_DEFEATED_FLAG
 cmp #2
 beq @finished
 lda N_BOSS_DEFEATED_FLAG
 bmi @native
 ; Do not retrigger electrocution or restart a room advance every frame
 ; that Up remains held. The native jump out of a transition owns its
 ; complete trajectory, and hands its final state back to Mario.
 lda N_INDOOR_PLAYER_ADV_FLAG,x
 ora N_INDOOR_PLAYER_JUMP_FLAG,x
 ora N_ELECTROCUTED_TIMER,x
 bne @native
 cpx #0
 bne :+
 lda $604E
 jmp @script
:
 lda $60CE
@script:
 beq @input
 lda N_PLAYER_JUMP_STATUS,x
 bne @native
@input:
 lda N_LEVEL_LOCATION_TYPE
 and #1
 beq @state
 lda N_CONTROLLER_STATE,x
 and #8
 beq @state
 lda N_PLAYER_JUMP_STATUS,x
 bne @state
 ldy #1
 jsr N_d_pad_up_pressed
 ldx G_PLAYER
@state:
 lda N_INDOOR_PLAYER_ADV_FLAG,x
 ora N_INDOOR_PLAYER_JUMP_FLAG,x
 ora N_ELECTROCUTED_TIMER,x
 bne @native
 jsr N_set_player_aim_for_input
 jsr Enter
 jsr Move
 jsr Supplies
 jsr Leave
 ldx G_PLAYER
 jsr FireGate
 jmp N_auto_scroll_player
@native:
 jsr N_set_player_aim_for_input
 jsr N_player_state_routine_01_logic+3
 jsr Enter
 jsr SyncNative
 jsr Leave
 ldx G_PLAYER
@finished:
 rts
RenderGate:
 stx G_PLAYER
 lda N_PLAYER_STATE,x
 cmp #2
 beq @native
 lda N_INDOOR_PLAYER_ADV_FLAG,x
 ora N_INDOOR_PLAYER_JUMP_FLAG,x
 ora N_ELECTROCUTED_TIMER,x
 bne @native
 lda N_BOSS_DEFEATED_FLAG
 beq @done
@native:
 ldy #2
 jsr N_load_bank_number
 jsr N_set_player_sprite_and_attrs
 ldx G_PLAYER
@done:
 rts
DrawGate:
 lda N_GAME_ROUTINE_INDEX
 cmp #2
 beq @gameplay
 cmp #5
 bne @native
@gameplay:
 lda N_LEVEL_ROUTINE_INDEX
 cmp #3
 bcc @native
 cmp #$0B
 bcs @native
 lda #1
 sta G_RENDER_ACTIVE
 ldx #1
@players:
 lda N_CPU_SPRITE_BUFFER,x
 cmp #$91
 beq @keepElevator
 lda #0
 sta N_CPU_SPRITE_BUFFER,x
@keepElevator:
 dex
 bpl @players
 jsr Enter
 jsr Items
 jsr Leave
 ldy #1
 jsr N_set_rom_bank_to_y
 jsr N_draw_sprites
 jsr Enter
 jsr Compose
 jmp Leave
@native:
 lda #0
 sta G_RENDER_ACTIVE
 lda N_GAME_ROUTINE_INDEX
 cmp #5
 beq :+
 lda #0
 sta G_INVINCIBLE
 sta G_CHEAT_ARMED
 sta G_CHEAT_SEQUENCE
 sta G_CHEAT_SEQUENCE+1
:
 lda #$64
 sta G_DMA
 lda G_TITLE_ACTIVE
 beq :+
 jmp TitleDraw
:
 jmp N_draw_sprites
DmaGate:
 jmp UploadDma
AssetsGate:
 lda N_GAME_ROUTINE_INDEX
 cmp #2
 beq @gameplay
 cmp #5
 jne @native
@gameplay:
 lda #0
 sta G_TITLE_ACTIVE
 txa
 pha
 tya
 pha
 lda #0
 sta $2000
 sta $2001
 jsr Enter
 ; Extra rifle angles live in bank 9 and use retired player-only CHR.
 ; This fixed-bank code runs while both NMI and rendering are disabled.
 ldy #9
 jsr N_set_rom_bank_to_y
 bit $2002
 lda #4
 sta $2006
 lda #$20
 sta $2006
 ldx #0
@angleFirst:
 lda $8001,x
 sta $2007
 inx
 bne @angleFirst
 lda #8
 sta $2006
 lda #0
 sta $2006
@angleSecond:
 lda $8101,x
 sta $2007
 inx
 bne @angleSecond
 ; Directional body frames are cached in unused WRAM for base hallways.
 ; Keeping the cache here avoids changing the mapper during live drawing.
@backPages:
 .repeat 13,I
  lda $8201+I*$100,x
  sta $6900+I*$100,x
 .endrepeat
 inx
 bne @backPages
@backTail:
 lda $8F01,x
 sta $7600,x
 inx
 cpx #128
 bne @backTail
 ldy #8
 jsr N_set_rom_bank_to_y
 jsr Prepare
 jsr Leave
 pla
 tay
 pla
 tax
@native:
 lda #5
 sta N_PPU_READY
 jmp N_configure_PPU+4
FireGate:
 stx G_PLAYER
 jsr Enter
 jsr SpawnFire
 jsr Leave
 ldx G_PLAYER
 ldy #6
 jsr N_load_bank_number
 jmp N_check_player_fire
BulletGate:
 ldy #6
 jsr N_load_bank_number
 jsr N_run_player_bullet_routines
 jsr Enter
 jsr Fireballs
 jmp Leave
DamageGate:
 stx G_PLAYER
 lda N_SPRITE_Y_POS,x
 cmp #$E8
 bcs @dead
 lda G_INVINCIBLE
 bne @exit
 tya
 pha
 jsr Enter
 jsr Damage
 sta G_RESULT
 jsr Leave
 pla
 tay
 ldx G_PLAYER
 lda G_RESULT
 bne @exit
@dead:
 lda #$52
 jsr N_play_sound
 jmp N_kill_player+5
@exit: rts
PickupGate:
 ldy N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_ATTRIBUTES,y
 bmi @supply
 stx $10
 lda #$0A
 sta $00
 jmp N_pick_up_weapon_item+6
@supply:
 stx G_PLAYER
 lda #$0A
 sta $00
 txa
 tay
 jsr N_add_player_low_score
 jsr Enter
 jsr Collect
 jsr Leave
 ldx N_ENEMY_CURRENT_SLOT
 jmp N_remove_enemy
CollisionGate:
 lda N_ENEMY_CURRENT_SLOT
 sta G_SLOT
 jsr Enter
 jsr Stomps
 jsr Leave
 jmp N_check_players_collision
EnemyGate:
 jsr N_exe_enemy_routine
 ldx N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_SPRITES,x
 beq @done
 stx G_SLOT
 jsr Enter
 jsr Stomps
 jsr FireEnemies
 jsr Leave
 ldx N_ENEMY_CURRENT_SLOT
@done: rts
PlayerBoxGate:
 ; Start with Contra's enemy shape expanded for a 4x4 projectile,
 ; then expand it for Mario's 14x16 or 14x32 inner body instead.
 lda N_PLAYER_HIDDEN,x
 beq @visible
 lda #0
 sta $0A
 rts
@visible:
 ; Moving platforms need the native narrow landing plane. Expanding it
 ; like a damaging enemy catches players from the side and pins them.
 ldy N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_STATE_WIDTH,y
 and #$60
 cmp #$40
 bne @body
 ldy #1
 jmp N_set_enemy_collision_box
@body:
 ldy #4
 jsr N_set_enemy_collision_box
 lda $08
 sec
 sbc #10
 sta $08
 lda $09
 sec
 sbc #5
 sta $09
 lda $0B
 clc
 adc #10
 sta $0B
 cpx #0
 bne @p1
 lda $6004
 beq @small
 lda $601D
 bne @small
 beq @big
@p1:
 lda $6084
 beq @small
 lda $609D
 bne @small
@big:
 lda #28
 bne @height
@small:
 lda #12
@height:
 clc
 adc $0A
 sta $0A
 rts
SolidGate:
 pha
 lda G_CUSTOM_MOVE
 beq @native
 pla
 clc
 rts
@native:
 pla
 clc
 adc N_SPRITE_X_POS,x
 jmp N_check_player_solid_bg_collision+4
OamStartGate:
 lda N_OAMDMA_CPU_BUFFER_OFFSET
 clc
 adc #$4C
 tax
 lda G_RENDER_ACTIVE
 beq @native
@skip:
 cpx #64
 bcs @start
 jsr OamAdvanceGate
 jmp @skip
@start:
 ldy #47
 bne @store
@native:
 ldy #63
@store:
 stx N_OAMDMA_CPU_BUFFER_OFFSET
 stx $04
 sty $07
 rts
OamAdvanceGate:
 txa
 clc
 adc #$C4
 tax
 lda G_RENDER_ACTIVE
 beq @done
 cpx #64
 bcc OamAdvanceGate
@done:
 rts
ResetGate:
 stx G_PLAYER
 lda #0
 sta G_FIRE_ACTIVE,x
 sta G_FIRE_ACTIVE+2,x
 lda #0
 cpx #0
 bne @p1
 sta $6000
 sta $6004
 beq @native
@p1:
 sta $6080
 sta $6084
@native:
 sta N_P1_CURRENT_WEAPON,x
 jmp N_init_player_attributes
DemoEndGate:
 ; Mario's movement can queue a final terrain block on the very frame the
 ; recorded demo ends. It cannot be read using the title's text format.
 lda #0
 sta N_GRAPHICS_BUFFER_MODE
 sta N_CPU_GRAPHICS_BUFFER
 sta N_GRAPHICS_BUFFER_OFFSET
 sta G_PENDING
 sta G_PALETTE_DIRTY
 jmp N_set_game_routine_index_to_a
SessionGate:
 ; Native session setup clears internal RAM only. Invalidate both custom
 ; players so power, movement and the two supplies belong to this session.
 lda #0
 sta $6000
 sta $6004
 sta $6080
 sta $6084
 sta G_PENDING
 sta G_PALETTE_DIRTY
 sta G_FIRE_ACTIVE
 sta G_FIRE_ACTIVE+1
 sta G_FIRE_ACTIVE+2
 sta G_FIRE_ACTIVE+3
 jmp N_clear_memory_3
PaletteGate:
 lda N_GRAPHICS_BUFFER_OFFSET
 cmp #$30
 jcs @done
 lda N_NUM_PALETTES_TO_LOAD
 ora G_PALETTE_DIRTY
 jeq @done
 lda N_PPUCTRL_SETTINGS
 and #$18
 sta $2000
 bit $2002
 lda #$3F
 sta $2006
 lda #0
 sta $2006
 .repeat 32,I
  lda N_PALETTE_CPU_BUFFER+I
  sta $2007
 .endrepeat
 lda #$3F
 sta $2006
 lda #0
 sta $2006
 sta $2006
 sta $2006
 sta N_NUM_PALETTES_TO_LOAD
 sta G_PALETTE_DIRTY
@done: rts
PauseGate:
 jsr N_check_for_pause
 jsr Enter
 jsr CheatInput
 jmp Leave
ScrollGate:
 lda N_LEVEL_LOCATION_TYPE
 bne @done
 lda N_LEVEL_SCROLLING_TYPE
 bne @vertical
 ldx #0
@player:
 lda N_FRAME_SCROLL
 ldy N_PLAYER_FRAME_SCROLL,x
 beq @offset
 sec
 cpx #0
 bne @p1
 sbc $604B
 jmp @offset
@p1:
 sbc $60CB
@offset:
 sta G_TMP
 lda N_SPRITE_X_POS,x
 sec
 sbc G_TMP
 sta N_SPRITE_X_POS,x
 inx
 cpx #2
 bne @player
 rts
@vertical:
 jmp N_scroll_player+17
@done: rts

BridgeTileGate:
 ; Bridge animations can lag behind SMB running speed. Their draw X is
 ; enemy X minus 44 (previous section) or 12 (current section). Preserve
 ; that signed coordinate when selecting the nametable and its CPU cache.
 sta $F3
 sty $F7
 ldy #3
 jsr N_load_bank_number
 lda $F3
 sta $11
 lda N_GRAPHICS_BUFFER_OFFSET
 cmp #$40
 bcs @restore
 ldy $F7
 jsr N_set_ppu_addresses_in_mem
 ldx N_ENEMY_CURRENT_SLOT
 lda N_ENEMY_VAR_2,x
 bne @current
 lda N_ENEMY_X_POS,x
 cmp #44
 bcs @draw
 bcc @negative
@current:
 lda N_ENEMY_X_POS,x
 cmp #12
 bcs @draw
@negative:
 lda $13
 eor #4
 sta $13
 sta $0D
 lda $15
 eor #4
 sta $15
 lda $02
 eor #$40
 sta $02
@draw:
 ; Continue after the original queue guard and address calculation.
 jsr N_update_nametable_supertile+11
@restore:
 jmp N_load_previous_bank

TitleInit:
 jsr N_zero_out_nametables
 jsr TitleGate
 ldy #0
 sty N_KONAMI_CODE_NUM_CORRECT
 iny
 sty N_HORIZONTAL_SCROLL
 iny
 sty N_DELAY_TIME_HIGH_BYTE
 lda #$A0
 sta N_PPUCTRL_SETTINGS
 jmp N_inc_routine_index_set_timer
TitleGate:
 jsr N_load_intro_graphics
 lda N_BANK_NUMBER
 pha
 ldy #10
 jsr N_set_rom_bank_to_y
 jsr TitleLoad
 pla
 tay
 jmp N_set_rom_bank_to_y
TitleTheme:
 lda #0
 sta N_HORIZONTAL_SCROLL
 lda #$A0
 sta N_PPUCTRL_SETTINGS
 lda #$A4
 sta N_INTRO_THEME_DELAY
 lda #$26
 jmp N_play_sound
TitleScroll:
 lda $2002
 lda G_TITLE_ACTIVE
 beq @native
 lda #0
 jmp N_set_ppu_scroll+5
@native:
 jmp N_set_ppu_scroll+3
TitleRaster:
 lda G_TITLE_ACTIVE
 beq @done
 lda N_PPU_READY
 bne @done
@clearHit:
 bit $2002
 bvs @clearHit
@hit:
 bit $2002
 bvc @hit
 ldx #10
@delay:
 dex
 bne @delay
 lda #$B0
 sta $2000
@done:
 rts
TitleBlinkGate:
 lda G_TITLE_ACTIVE
 beq @done
 lda N_GAME_ROUTINE_INDEX
 cmp #1
 beq @animate
 cmp #3
 bne @done
@animate:
 lda N_BANK_NUMBER
 pha
 ldy #10
 jsr N_set_rom_bank_to_y
 jsr TitleAnimate
 pla
 tay
 jmp N_set_rom_bank_to_y
@done:
 rts
.segment "VBLANK"
TitleOne:
 jsr N_game_routine_01
 jmp TitleBlinkGate
TitleThree:
 jsr N_game_routine_03
 ; Its original flashing labels use obsolete title tiles/coordinates.
 lda #0
 sta N_CPU_GRAPHICS_BUFFER
 sta N_GRAPHICS_BUFFER_OFFSET
 jmp TitleBlinkGate
TitleFour:
 ; The original title and lives screen share a font atlas. Our custom
 ; title replaces that atlas, so restore it before the first lives screen.
 lda #0
 sta G_TITLE_ACTIVE
 lda #$0A
 jsr N_load_A_offset_graphic_data
 jmp N_game_routine_04
TitleDraw:
 ldx N_PLAYER_MODE
 lda TitleCursorY,x
 sta $6404
 lda N_GAME_ROUTINE_INDEX
 cmp #3
 bne @done
 lda N_FRAME_COUNTER
 and #8
 beq @done
 lda #$F8
 sta $6404
@done:
 ; Demo initialization takes one frame before its forced-blank load.
 ; The title still owns the display then, regardless of game-routine ID.
 jmp TitleRaster
TitleCursorY: .byte 151,167
.segment "TITLEASSETS"
 .incbin "build/title-assets.bin"
.segment "TITLECODE"
TitleLoad:
 lda #0
 sta $2000
 sta $2001
 sta G_PENDING
 sta G_PALETTE_DIRTY
 sta N_CPU_GRAPHICS_BUFFER
 sta N_GRAPHICS_BUFFER_OFFSET
 sta N_NUM_PALETTES_TO_LOAD
 bit $2002
 sta $2006
 sta $2006
 lda #1
 sta $08
 lda #$80
 sta $09
 ldx #32
 jsr TitlePages
 lda #$20
 sta $2006
 lda #0
 sta $2006
 lda #1
 sta $08
 lda #$A0
 sta $09
 ldx #4
 jsr TitlePages
 lda #$24
 sta $2006
 lda #0
 sta $2006
 lda #$A0
 sta $09
 ldx #4
 jsr TitlePages
 bit $2002
 lda #$3F
 sta $2006
 lda #0
 sta $2006
 ldx #0
@palette:
 lda $A401,x
 sta N_PALETTE_CPU_BUFFER,x
 sta $7900,x
 sta $2007
 inx
 cpx #32
 bne @palette
 ldx #0
@oam:
 lda $A421,x
 sta $7800,x
 sta $6400,x
 inx
 bne @oam
 lda #1
 sta G_TITLE_ACTIVE
 lda #144
 sta G_BLINK_TIMER
 lda #213
 sta G_BLINK_TIMER+1
 lda #$5D
 sta G_BLINK_SEED
 lda #$B7
 sta G_BLINK_SEED+1
 lda #0
 sta G_BLINK_PHASE
 sta G_BLINK_PHASE+1
 sta G_BLINK_DISPLAY
 sta G_BLINK_DISPLAY+1
 lda #$A0
 sta N_PPUCTRL_SETTINGS
 lda #5
 sta N_PPU_READY
 lda #$A0
 sta $2000
 rts
TitlePages:
 ldy #0
@page:
 lda ($08),y
 sta $2007
 iny
 bne @page
 inc $09
 dex
 bne @page
 rts
TitleAnimate:
 ldx #1
@player:
 dec G_BLINK_TIMER,x
 bne @next
 inc G_BLINK_PHASE,x
 lda G_BLINK_PHASE,x
 cmp #6
 bcc @short
 lda #0
 sta G_BLINK_PHASE,x
 ; Each brother owns his rest timer, phase and independent LFSR.
 lda G_BLINK_SEED,x
 asl
 bcc :+
 eor #$1D
:
 sta G_BLINK_SEED,x
 and #63
 clc
 adc #144
 bne @timer
@short:
 lda #6
@timer:
 sta G_BLINK_TIMER,x
 ldy G_BLINK_PHASE,x
 lda TitlePhaseState,y
 sta G_BLINK_DISPLAY,x
 cpx #0
 beq :+
 clc
 adc #3
:
 tay
 lda TitleBlinkLo,y
 sta $08
 lda TitleBlinkHi,y
 sta $09
 txa
 pha
 jsr TitleQueueBlink
 pla
 tax
@next:
 dex
 bpl @player
 rts
TitlePhaseState: .byte 0,1,2,0,1,2
TitleQueueBlink:
 ; Add only tile references to the native vblank queue; all CHR is
 ; preloaded. The matching eye overlay uses the same next-frame OAM DMA.
 ldy #0
 lda ($08),y
 sta $0A
 ldx N_GRAPHICS_BUFFER_OFFSET
@tiles:
 iny
 lda ($08),y
 sta N_CPU_GRAPHICS_BUFFER,x
 inx
 dec $0A
 bne @tiles
 stx N_GRAPHICS_BUFFER_OFFSET
 lda #0
 sta N_CPU_GRAPHICS_BUFFER,x
 iny
 lda ($08),y
 sta $0A
 beq @done
@sprites:
 iny
 lda ($08),y
 tax
 iny
 lda ($08),y
 sta G_FINAL_OAM+1,x
 iny
 lda ($08),y
 sta G_FINAL_OAM+2,x
 dec $0A
 bne @sprites
@done:
 rts
.include "build/title-blink.inc"

.segment "ASSETS"
MarioFrames: .incbin "build/mario-base-frames.chr"
RecoilPatches: .incbin "build/mario-recoil.bin"
.include "build/sprite-data.inc"
RifleChr: .incbin "build/rifles.chr"
ItemChr: .incbin "build/items.chr"
FireChr: .incbin "build/fire.chr"
Stompable: .incbin "build/stompable.bin"
.repeat 4,C
 .ident(.sprintf("Collision%d",C)):
 .repeat 256,V
  .if ((V >> ((3-C)*2)) & 3) = 3
   .byte $80
  .else
   .byte (V >> ((3-C)*2)) & 3
  .endif
 .endrepeat
.endrepeat

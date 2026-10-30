.setcpu "6502"
.macpack longbranch
.include "state.inc"
.include "native.inc"
.export Boot,Motion,DrawGate,ContactGate,WeaponPhysics,FireSpawn,Init,X_Physics,GetPlayerAnimSpeed,ImposeFriction
.export M_STATE,M_SMB_X_SPEED,M_SMB_X_FORCE,M_VY,M_VY_FRAC,M_HELD,M_PREV,M_POSE,M_MAGIC,M_GRACE
.export WaterGate,MenuLoad,TitleDraw,WeaponDispatch,BossWeaponDispatch,MenuTitlePose,GetPalette,WeaponWait
.segment "BOOT"
Boot:
 ; Called after native MMC1 initialization and before title/NMI start.
 lda #0
 sta M_MAGIC
 sta $0D
@chunk:
 ldx $0D
 lda BootBanks,x
 jsr N_bank_switch
 ldx $0D
 lda BootSourcesLo,x
 sta $08
 lda BootSourcesHi,x
 sta $09
 lda BootDestHi,x
 sta $0B
 lda BootPages,x
 tax
 lda #0
 sta $0A
 ldy #0
@copy:
 lda ($08),y
 sta ($0A),y
 iny
 bne @copy
 inc $09
 inc $0B
 dex
 bne @copy
 inc $0D
 lda $0D
 cmp #3
 bne @chunk
 ; Decode the packed image from temporary $7400-$7DFF into $6000.
 lda #0
 sta $08
 sta $0A
 lda #$74
 sta $09
 lda #$60
 sta $0B
 ldy #0
@token:
 jsr BootRead
 beq @decoded
 bmi @match
 tax
@literal:
 jsr BootRead
 jsr BootWrite
 dex
 bne @literal
 beq @token
@match:
 and #$7F
 clc
 adc #3
 tax
 jsr BootRead
 sta $04
 jsr BootRead
 sta $05
@back:
 lda ($04),y
 jsr BootWrite
 inc $04
 bne :+
 inc $05
:
 dex
 bne @back
 beq @token
@decoded:
 lda #$0E
 jsr N_bank_switch
 lda #3
 sta N_current_lives
 lda #0
 sta N_current_etanks
 rts
BootRead:
 lda ($08),y
 inc $08
 bne :+
 inc $09
:
 ora #0
 rts
BootWrite:
 sta ($0A),y
 inc $0A
 bne :+
 inc $0B
:
 rts
BootBanks: .byte $0F,$0A,$0E
BootSourcesLo: .byte $00,$80,$80
BootSourcesHi: .byte $F4,$BB,$BD
BootDestHi: .byte $74,$79,$7D
BootPages: .byte 5,4,2
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
@done: rts
ReadInput:
 lda M_HELD
 sta M_PREV
 lda #0
 sta M_HELD
 lda $23
 ldx #8
@reverse:
 lsr
 rol M_HELD
 dex
 bne @reverse
 rts
Motion:
 jsr Init
 jsr ReadInput
 jsr FireSpawn
 lda $AA
 and #4
 jne @done
 lda $2C
 cmp #3
 jcc @script
 cmp #9
 jcs @script
 lda #0
 sta $37
 sta M_NATIVE
 lda $04A0
 sta M_PREV_Y
 lda M_GRACE
 beq :+
 dec M_GRACE
:
 lda M_RUNNING_TIMER
 beq :+
 dec M_RUNNING_TIMER
:
 lda M_SWIM_TIMER
 beq :+
 dec M_SWIM_TIMER
:
 jsr Environment
 jsr N_player_check_fire_weapon ; native ladder entry unwinds this call as usual
 lda M_STATE
 bne @input
 lda $35
 pha
 lda #0
 sta $35
 lda $04A0
 sta $2E
 clc
 adc #12
 sta $0A
 lda $F9
 adc #0
 sta $0B
 jsr N_player_floor_tile_check
 pla
 sta $35
 jsr N_check_platform_collision
 bcs @input
 lda $00
 bne @input
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
 lda M_SWIMMING
 beq @landAir
 jsr GetPlayerAnimSpeed
 lda M_INPUT_DIR
 beq @move
 sta M_FACING
@landAir:
 lda M_INPUT_DIR
 beq @move
@friction:
 jsr ImposeFriction
@move:
 jsr Horizontal
 jsr Vertical
 ldx #1
 lda M_SMB_X_SPEED
 beq @facing
 bpl :+
 inx
:
 stx M_MOVING_DIR
@facing:
 lda M_FACING
 cmp #2
 lda $0420
 and #$BF
 bcs :+
 ora #$40
:
 sta $0420
 ldx #6
 lda M_STATE
 beq :+
 ldx #3
:
 stx $2C
 jsr N_player_set_sprite
@done: rts
@script:
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_RUNNING_TIMER
 sta M_GRACE
 lda #1
 sta M_NATIVE
 lda #2
 sta M_STATE
 lda #$70
 sta M_GRAVITY
 sta M_FALL_FORCE
 lda #0
 sta M_SWIMMING
 sta M_SWIM_TIMER
 lda #1
 sta M_AREA_TYPE
 ; Import native knockback/scripted velocity for a smooth return.
 lda #0
 sec
 sbc $0660
 sta M_VY_FRAC
 lda #0
 sbc $0640
 sta M_VY
 lda $2C
 jmp N_entity_dispatch_setup
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
 sta $04C0
 lda $04A0
 sta M_JUMP_ORIGIN
 lda #1
 sta M_STATE
 lda #32
 sta M_SWIM_TIMER
 lda #$29
 jsr N_sound_queue_push
@done: rts
JumpForce: .byte $20,$20,$1E,$28,$28,$0D
FallForce: .byte $70,$70,$60,$90,$90,$0A
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB,$FE
Environment:
 lda M_NATIVE_WATER
 bne @water
 lda M_SWIMMING
 beq @dry
 lda #$70
 sta M_FALL_FORCE
 lda M_VY
 bmi @dry
 lda #$70
 sta M_GRAVITY
@dry:
 lda #0
 sta M_SWIMMING
 lda #1
 sta M_AREA_TYPE
 rts
@water:
 lda M_SWIMMING
 bne @wet
 lda #0
 sta M_SMB_X_FORCE
 sta M_RUNNING_SPEED
 sta M_RUNNING_TIMER
 sta $0480
 lda M_SMB_X_SPEED
 bmi @left
 cmp #$11
 bcc @wet
 lda #$10
 bne @limit
@left:
 cmp #$F0
 bcs @wet
 lda #$F0
@limit:
 sta M_SMB_X_SPEED
@wet:
 lda #1
 sta M_SWIMMING
 lda #0
 sta M_AREA_TYPE
 lda #$0A
 sta M_FALL_FORCE
 rts
WaterGate:
 txa
 sta M_NATIVE_WATER
 lda N_gravity_hi_table,x
 jmp N_ground_store_params+3
Horizontal:
 lda M_SMB_X_SPEED
 sta M_TMP
 bpl @positive
 eor #$FF
 clc
 adc #1
@positive:
 pha
 asl
 asl
 asl
 asl
 sta $0620
 pla
 lsr
 lsr
 lsr
 lsr
 sta $0600
 lda #$40
 ldx M_TMP
 bpl :+
 lda #0
:
 sta $42
 lda M_STATE
 bne @conveyorDone
 lda $40
 and #$0F
 beq @conveyorDone
 lda $0420
 and #$BF
 ora $42
 sta $0420
 jsr N_player_handle_conveyor
@conveyorDone:
 lda $0460
 sta M_LAST_X
 lda $42
 and #$40
 beq @expectLeft
 clc
 lda $0480
 adc $0620
 lda $0460
 adc $0600
 jmp @expect
@expectLeft:
 sec
 lda $0480
 sbc $0620
 lda $0460
 sbc $0600
@expect:
 sta M_EXPECT_X
 jsr N_player_horiz_movement
 lda M_SMB_X_SPEED
 beq @done
 lda $0460
 cmp M_EXPECT_X
 beq @done
 lda $0480
 bne @done
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
@done: rts
Vertical:
 lda M_STATE
 bne @air
 rts
@air:
 lda M_VY
 bpl @fallForce
 lda M_HELD
 and #$80
 and M_PREV
 bne @position
 lda M_JUMP_ORIGIN
 sec
 sbc $04A0
 cmp #1
 bcc @position
@fallForce:
 lda M_FALL_FORCE
 sta M_GRAVITY
@position:
 lda #0
 sec
 sbc M_VY_FRAC
 sta $0660
 lda #0
 sbc M_VY
 sta $0640
 lda $35
 pha
 lda #0
 sta $35
 lda $30
 pha
 lda $31
 pha
 lda #0
 sta $30
 sta $31
 jsr N_player_vertical_physics
 pla
 sta $31
 pla
 sta $30
 pla
 sta $35
 lda $0640
 ora $0660
 bne @gravity
 lda M_VY
 ora M_VY_FRAC
 beq @gravity
 lda M_VY
 bmi @ceiling
 lda #0
 sta M_STATE
 sta M_VY
 sta M_VY_FRAC
 sta $04C0
 rts
@ceiling:
 lda #1
 sta M_VY
 lda #0
 sta M_VY_FRAC
 lda M_FALL_FORCE
 sta M_GRAVITY
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
DrawGate:
 ; Enter after native animation advances; preserve teleport/death dispatch.
 cpx #0
 beq @mario
 pha
 cpx #8
 bcs @other
 cpx #6
 bcc @other
 lda $0400,x
 cmp #$23
 bne @other
 pla
 jmp DrawFireball
@other:
 pla
 tay
 cpx #1
 jmp N_render_skip_flash
@mario:
 jsr Init
 lda $F9
 jne @skip
 lda N_invincibility_timer
 beq @visible
 dec N_invincibility_timer
 lda $1C
 and #2
 jne @skip
@visible:
 lda #3
 sta M_POSE
 lda $2C
 cmp #9
 bcc @motion
 cmp #$0B
 bcs @motion
 lda $0680
 and #1
 clc
 adc #7
 bne @setPose
@motion:
 lda M_NATIVE
 bne @environmentPose
 lda $36
 cmp #8
 bcc @environmentPose
 lda #9
 jmp @setPose
@environmentPose:
 lda M_SWIMMING
 beq @landMotion
 lda M_STATE
 beq @landMotion
 lda $1C
 lsr
 lsr
 lsr
 and #3
 cmp #3
 bne :+
 lda #1
:
 clc
 adc #19
 jmp @setPose
@landMotion:
 lda M_STATE
 beq @ground
 lda M_NATIVE
 bne @ground
 lda #4
 bne @setPose
@ground:
 lda M_NATIVE
 bne @scriptWalk
 lda M_SMB_X_SPEED
 beq @ready
 bne @animate
@scriptWalk:
 lda $0460
 cmp M_LAST_X
 beq @ready
@animate:
 inc M_TIMER
 lda M_TIMER
 cmp M_ANIM_SET
 bcc @cycle
 lda #0
 sta M_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc @cycle
 lda #0
 sta M_ANIM
@cycle:
 lda M_ANIM
@setPose: sta M_POSE
@ready:
 lda M_POSE
 asl
 asl
 asl
 sta M_TILE
 sec
 lda $0460
 sbc $1F
 sec
 sbc #8
 sta M_OAMX
 lda $04A0
 sec
 sbc #21
 sta M_OAMY
 lda $0420
 and #$40
 eor #$40
 sta M_ATTR
 lda #0
 sta M_INDEX
 ldx $06
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
 beq @full
 inc M_TILE
 inc M_INDEX
 lda M_INDEX
 cmp #8
 bne @sprite
 stx $06
@skip: clc
 rts
@full: stx $06
 sec
 rts
ContactGate:
 ; Stomp before native damage. Only ordinary, exposed, shootable enemies.
 lda #0
 sta $01
 lda M_NATIVE
 jne @native
 lda $2C
 cmp #3
 jcc @native
 cmp #9
 jcs @native
 cpx #$10
 jcc @native
 lda $0420,x
 and #$0B
 cmp #3
 jne @native
 ldy $0400,x
 lda Stompable,y
 jeq @native
 ldy $06E0,x
 lda N_contact_damage_range_y_tbl,y
 sec
 sbc #12
 sta M_TMP
 lda $04A0,x
 sec
 sbc M_TMP
 sta M_TMP
 lda M_VY
 bmi @grace
 lda M_PREV_Y
 clc
 adc #12
 sec
 sbc M_TMP
 cmp #5
 bcc @testX
 cmp #$E8
 bcc @grace
@testX:
 lda $04A0
 clc
 adc #14
 sec
 sbc M_TMP
 cmp #$F8
 bcs @grace
 lda $2D
 sec
 sbc $2E
 bcs :+
 eor #$FF
 adc #1
:
 cmp #20
 bcs @grace
 ; Native death bookkeeping, explosions and drops remain host-owned.
 jsr N_item_drop_rng
 lda #$80
 sta $0420,x
 lda #$06
 sta $0400,x
 lda #0
 sta $0680,x
 sta $06A0,x
 sta $06C0,x
 lda #$FC
 sta M_VY
 lda #0
 sta M_VY_FRAC
 lda #1
 sta M_STATE
 lda #$20
 sta M_GRAVITY
 lda #$70
 sta M_FALL_FORCE
 lda #8
 sta M_GRACE
 rts
@grace:
 lda M_GRACE
 bne @return
@native:
 jmp N_check_player_collision+4
@return: rts
FireSpawn:
 ; Two private native entity slots; native guns and items use slots 2-5.
 lda $AA
 and #4
 bne @done
 lda $2C
 cmp #3
 bcc @clear
 cmp #$0B
 bcs @clear
 lda M_HELD
 and #$40
 beq @done
 and M_PREV
 bne @done
 ldx #7
 lda $0420,x
 bpl @spawn
 dex
 lda $0420,x
 bmi @done
@spawn:
 ldy #0
 jsr N_weapon_spawn_projectile
 lda #0
 sta M_FB_AGE,x
 lda #4
 sta $0600,x
 lda #$FF
 sta $0640,x
 lda #$80
 sta $0660,x
@done: rts
@clear:
 lda #0
 sta $0426
 sta $0427
 rts
WeaponDispatch:
 cpx #6
 bcc @native
 cpx #8
 bcs @native
 jmp N_weapon_hit_buster
@native:
 ldy N_current_weapon
 lda N_weapon_handler_ptr_lo,y
 jmp N_weapon_collision_dispatch+5
BossWeaponDispatch:
 cpx #6
 bcc @native
 cpx #8
 bcs @native
 jmp N_boss_hit_buster
@native:
 ldy N_current_weapon
 lda $A930,y
 jmp N_weapon_boss_hit_dispatch+9
WeaponPhysics:
 cpx #8
 jcs @native
 cpx #6
 jcc @native
 lda $0400,x
 cmp #$23
 jne @native
 lda $AA
 and #4
 jne @native
 inc M_FB_AGE,x
 lda M_FB_AGE,x
 cmp #100
 jcs @expire
 lda $04A0,x
 cmp #$E8
 jcs @expire
 lda $04A0,x
 sta $0A
 lda #0
 sta $0B
 lda $0420,x
 and #$40
 beq @aheadLeft
 clc
 lda $0460,x
 adc #4
 sta $08
 lda $0440,x
 adc #0
 jmp @ahead
@aheadLeft:
 sec
 lda $0460,x
 sbc #4
 sta $08
 lda $0440,x
 sbc #0
@ahead:
 sta $09
 jsr N_lookup_cached_tile
 ldx $2B
 lda $00
 and #1
 jne @expire
 ; Bouncing native buster: terrain probes use the same stage cache.
 jsr N_entity_physics_core
 ldx $2B
 lda $0420,x
 bpl @return
 lda $0460,x
 sta $08
 lda $0440,x
 sta $09
 lda $04A0,x
 clc
 adc #4
 sta $0A
 lda #0
 sta $0B
 jsr N_lookup_cached_tile
 ldx $2B
 lda $00
 and #1
 beq @gravity
 lda $0640,x
 bpl @expire
 lda $04A0,x
 and #$F0
 sec
 sbc #4
 sta $04A0,x
 lda #3
 sta $0640,x
 lda #0
 sta $0660,x
@gravity:
 lda $0660,x
 sec
 sbc #$50
 sta $0660,x
 lda $0640,x
 sbc #0
 sta $0640,x
@return: rts
@expire:
 lsr $0420,x
 rts
@native:
 jmp N_entity_physics_core
DrawFireball:
 lda $0460,x
 sec
 sbc $1F
 sec
 sbc #4
 sta M_OAMX
 lda $04A0,x
 sec
 sbc #4
 sta M_OAMY
 ldx $06
 lda M_OAMX
 sta $0203,x
 lda M_OAMY
 sta $0200,x
 lda $1C
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
 stx $06
 beq @full
 clc
 rts
@full: sec
 rts
MenuLoad:
 sta BASE+50
 cmp #3
 beq :+
 sta BASE+51
:
 jsr N_chr_ram_bank_load
 lda BASE+50
 cmp #2
 beq @title
 cmp #3
 bne :+
 lda BASE+51
:
 cmp #6
 bne @done
 lda #<MenuBigArt
 sta $08
 lda #>MenuBigArt
 sta $09
 lda #8
 ldx #2
 bne @upload
@title:
 lda #<MenuTitleArt
 sta $08
 lda #>MenuTitleArt
 sta $09
 lda #0
 ldx #1
@upload:
 sta $2006
 lda #0
 sta $2006
 ldy #0
@copy:
 lda ($08),y
 sta $2007
 iny
 bne @copy
 inc $09
 dex
 bne @copy
@done:
 lda #$0D
 rts
TitleDraw:
 jsr MenuPalette
 jmp N_title_render_megaman
WeaponWait:
 jsr MenuPalette
 jmp N_wait_for_vblank_0D
MenuPalette:
 lda #$30
 sta N_palette_sprite+1
 lda #$27
 sta N_palette_sprite+2
 lda #$16
 sta N_palette_sprite+3
 rts
GetPalette:
 lda N_weapon_get_pal_lo,x
 sta N_palette_sprite+$0A
 lda N_weapon_get_pal_hi,x
 sta N_palette_sprite+$0B
 jsr MenuPalette
 jmp N_weapon_get_name_colors+18
.include "menus.inc"
.include "smb-land.inc"
.include "art.inc"
.include "stomp.inc"

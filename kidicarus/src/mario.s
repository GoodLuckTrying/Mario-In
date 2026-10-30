.setcpu "6502"
.macpack longbranch
.import __BRIDGES_LOAD__
.import __SCROLL_LOAD__
.import __VBLANK_LOAD__
.include "memory.inc"
.export Bootstrap, UpdateBridge, RenderBridge, DmaBridge, AssetsBridge
.export FireBridge, ContactBridge, DeathBridge, HitBridge, PickupBridge
.export PaletteBridge
.export TileAt, NativeTerrainEffect
.export LifeBridge
.export DyingBridge
.export DamageBridge
.export FireOne
.export ScrollBridge, HorizontalStream, VerticalStream
.export StageResetBridge
.export FastPalette
.export VideoEnableBridge, HitAltBridge
.export HammerHudBridge
.export MarioUpdate, MarioRender, Fireballs, MarioContact, TryStomp
.export ResolveSpawnSides
.export RoomVideoBridge
.export FortressStatsBridge, FortressMapBridge

.segment "BOOT"
Bootstrap:
    jsr $EB07
    lda #8
    jsr $C17F
    ldx #0
@copy:
    lda __BRIDGES_LOAD__,x
    sta $6100,x
    lda __BRIDGES_LOAD__+$100,x
    sta $6200,x
    lda __BRIDGES_LOAD__+$200,x
    sta $6300,x
    lda __BRIDGES_LOAD__+$300,x
    sta $6400,x
    lda __BRIDGES_LOAD__+$400,x
    sta $6500,x
    lda __BRIDGES_LOAD__+$500,x
    sta $6600,x
    lda __BRIDGES_LOAD__+$600,x
    sta $6700,x
    lda __SCROLL_LOAD__,x
    sta $6A00,x
    lda __SCROLL_LOAD__+$100,x
    sta $6B00,x
    lda __SCROLL_LOAD__+$200,x
    sta $6C00,x
    lda __VBLANK_LOAD__,x
    sta $6E00,x
    lda #0
    sta $6800,x
    sta $6900,x
    lda #$F8
    sta M_DMA_OAM,x
    inx
    bne @copy
    lda #0
    jmp $C17F

.segment "BRIDGES"
EnterBank:
    lda $B6
    sta M_BANK
    lda #8
    jmp $C17F
LeaveBank:
    lda M_BANK
    jmp $C17F
UpdateBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr MarioUpdate
    jsr LeaveBank
    pla
    sta M_BANK
    ldx #$20
    rts
RenderBridge:
    sta M_INPUT_A
    cpx #$20
    beq @mario
    lda M_INPUT_A
    cmp #$80
    bcs @special
    jmp $C4D2
@special:
    jmp $C667
@mario:
    lda M_BANK
    pha
    jsr EnterBank
    jsr MarioRender
    jsr LeaveBank
    pla
    sta M_BANK
    ldx #$20
    rts
AssetsBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr InstallAssets
    jsr LeaveBank
    pla
    sta M_BANK
    lda #$10
    jmp $CA90
; Finish player graphics while rendering and NMI are disabled. The first
; visible frame must use Mario CHR, OAM and colors together, including retries.
VideoEnableBridge:
    lda M_DISPLAY_PENDING
    beq @enable
    lda $A0
    cmp #2
    bcc @enable
    cmp #9
    bcs @enable
    lda $0100
    and #$7F
    sta $0100
    sta $2000
    lda #0
    sta $2001
    txa
    pha
    tya
    pha
    lda M_BANK
    pha
    jsr EnterBank
    jsr PrepareDisplay
    jsr LeaveBank
    pla
    sta M_BANK
    jsr StreamPalette
@vblank:
    bit $2002
    bpl @vblank
    jsr $EBC9
    lda #0
    sta $2003
    lda M_DMA_PAGE
    sta $4014
    pla
    tay
    pla
    tax
@enable:
    lda $0100
    ora #$80
    sta $0100
    sta $2000
    lda $FF
    sta $2001
    rts
FireBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr Fireballs
    jsr LeaveBank
    pla
    sta M_BANK
    rts
FortressHammerTerrain:
    lda #5
    jsr $C17F
    jsr $93EF
    lda #8
    jmp $C17F
HammerHudBridge:
    lda $3C
    beq @normal
    jmp $90DB
@normal:
    jmp $90CA
ContactBridge:
    jsr NearMarioX
    bcs @far
    stx M_CONTACT_SLOT
    lda M_BANK
    pha
    jsr EnterBank
    ldx M_CONTACT_SLOT
    jsr MarioContact
@finish:
    sta M_OUTPUT_A
    php
    jsr LeaveBank
    plp
    pla
    sta M_BANK
    lda M_OUTPUT_A
    ldx M_CONTACT_SLOT
    ldy #$20
    rts
@far:
    lda #$FF
    ldy #$20
    sec
    rts
HitBridge:
    lda #0
    beq HitCommon
HitAltBridge:
    lda #1
HitCommon:
    sta M_HIT_KIND
    jsr NearMarioX
    bcs @native
    stx M_CONTACT_SLOT
    lda M_BANK
    pha
    jsr EnterBank
    ldx M_CONTACT_SLOT
    jsr TryStomp
    php
    jsr LeaveBank
    plp
    pla
    sta M_BANK
    ldx M_CONTACT_SLOT
    bcs @native
    ldy #$38
    clc
    rts
@native:
    lda $3C
    bne @hammer
    lda M_HIT_KIND
    bne @alternate
    jmp $D994
@alternate:
    jmp $D9C0
@hammer:
    jmp $D9A9
NearMarioX:
    lda $0723
    sec
    sbc $0703,x
    bpl :+
    eor #$FF
    clc
    adc #1
:
    cmp #16
    rts
RoomVideoBridge:
    ; The native room NMI switches into bank 6 separately for text/palette
    ; and shop prices. Share one bank visit to leave time for Mario CHR.
    lda $B6
    pha
    lda #6
    jsr $C17F
    jsr $954C
    ; Prices persist in the nametable. Refresh them on the next frame
    ; without a Mario pose upload, so both transfers stay in vblank.
    lda M_CHR_UPLOADED
    bne :+
    jsr $8F4A
:
    pla
    jmp $C17F
FortressStatsBridge:
    lda M_CHR_UPLOADED
    bne @done
    lda $3A
    cmp #$0A
    jmp $8FBD
@done:
    rts
FortressMapBridge:
    lda M_CHR_UPLOADED
    bne @done
    lda $68
    asl
    jmp $8BB1
@done:
    rts
PickupBridge:
    sta M_INPUT_A
    txa
    pha
    lda M_BANK
    pha
    jsr EnterBank
    jsr HeartBonus
    jsr LeaveBank
    pla
    sta M_BANK
    pla
    tax
    lda M_INPUT_A
    sta $08
    jsr $DDEC
    jmp $DDD1
DeathBridge:
    lda M_BANK
    pha
    jsr EnterBank
    lda $0721
    and #$40
    beq @living
    jsr DeathMove
    jmp @restore
@living:
    jsr MarioUpdate
@restore:
    jsr LeaveBank
    pla
    sta M_BANK
    ldx #$20
    rts
PaletteBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr MarioPalette
    jsr ComposeOam
    jsr LeaveBank
    pla
    sta M_BANK
    rts
LifeBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr LoseLife
    php
    jsr LeaveBank
    plp
    pla
    sta M_BANK
    bcs @gameOver
    ldx #$FF
    txs
    jmp $C06D
@gameOver:
    lda $A0
    sta $AC
    jmp $C0A4
DyingBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr DeathMove
    jsr LeaveBank
    pla
    sta M_BANK
    ldx #$20
    rts
DamageBridge:
    lda M_BANK
    pha
    jsr EnterBank
    jsr CommonDamage
    jsr LeaveBank
    pla
    sta M_BANK
    lda $A6
    bne @survive
    jmp $DA6D
@survive:
    jmp $DA9B
StageResetBridge:
    cpx #$20
    bne @native
    lda #0
    sta M_PENDING_ATTR
    sta M_VRAM_NEXT
    sta M_DEAD
    sta M_STATE
    sta M_SWIMMING
    sta M_SWIM_TIMER
    sta M_FORCED_ENV
    sta M_POWER_FREEZE
    sta M_STOMP_GRACE
    sta M_STOMP_CHAIN
    sta M_CROUCH
    sta M_ITEM_KIND
    sta M_X_FRAC
    sta M_Y_FRAC
    sta M_RUNNING_SPEED
    sta M_RUNNING_TIMER
    sta M_SMB_X_SPEED
    sta M_SMB_X_FORCE
    sta M_SMB_X_ABS
    sta M_VY
    sta M_VY_FRAC
    lda #1
    sta M_FACING
    sta M_MOVING_DIR
    lda #$FF
    sta M_PREP_CELL
    sta M_PREP_PAGE
    sta M_DRAW_CELL
    sta M_DRAW_PAGE
    sta M_LAST_FRAME
    sta M_DISPLAY_PENDING
@native:
    lda #$90
    sta $0701,x
    jmp $C3C4
; Calls to native bank-dependent code execute from WRAM, with the original
; bank restored for their duration. Tile lookup takes Y=X pixel and A=Y pixel.
TileAt:
    jmp FastTileAt
NativeTileAt:
    sta M_PROBE_Y
    sty M_PROBE_X
    lda M_BANK
    jsr $C17F
    lda M_PROBE_Y
    ldy M_PROBE_X
    jsr $7F12
    sta M_TILE
    lda #8
    jsr $C17F
    lda M_TILE
    rts
NativeDeath:
    lda M_BANK
    jsr $C17F
    ldx M_CONTACT_SLOT
    ldy #$20
    lda #0
    sta $A6
    jsr $DA69
    lda #8
    jmp $C17F
NativeTerrainEffect:
    lda M_BANK
    jsr $C17F
    ldx #$20
    jsr $CD24
    lda #8
    jmp $C17F
; Upload only a changed Mario pose. Eight contiguous CHR tiles occupy the
; original Pit tiles $00-$07. The remaining native graphics are untouched.
DmaBridge:
    lda #0
    sta M_CHR_UPLOADED
    ; Pause/menu scripts own VRAM. Normal room gameplay ($37=2) must
    ; still animate Mario, including growth/shrink after enemy contact.
    lda $38
    jne @dma
    lda $37
    beq @outdoor
    cmp #2
    jne @dma
    ; Give queued room text and its two-row erases the whole vblank.
    ; Indoor gameplay has no outdoor row/column stream to wait for.
    lda $0104
    jne @dma
    lda $04E2
    cmp #$F0
    jcs @dma
    jmp @pose
@outdoor:
    lda M_VRAM_NEXT
    jne @dma
@pose:
    ; A brick erase and a full pose upload cannot share the vblank budget.
    lda M_ERASE_PENDING
    jne @dma
    ; The final stage uses the native automatic horizontal streamer.
    ; Its tile/attribute phases also reserve this frame's VRAM bandwidth.
    lda $A0
    cmp #8
    bne :+
    lda $FE
    and #$0F
    cmp #2
    jeq @dma
    cmp #3
    jeq @dma
:
    lda M_DIRTY
    jeq @dma
    lda #0
    sta M_DIRTY
    inc M_CHR_UPLOADED
    lda $0100
    and #$FB
    sta $2000
    bit $2002
    lda #0
    sta $2006
    sta $2006
    .repeat 128,I
        lda M_SPRITES+I
        sta $2007
    .endrepeat
    lda $0100
    sta $2000
@dma:
    lda M_ERASE_PENDING
    beq @oam
    lda #0
    sta M_ERASE_PENDING
    lda $0100
    and #$FB
    sta $2000
    bit $2002
    lda M_ERASE_HI
    sta $2006
    lda M_ERASE_LO
    sta $2006
    lda #$12
    sta $2007
    sta $2007
    lda M_ERASE_HI
    sta $2006
    lda M_ERASE_LO
    clc
    adc #32
    sta $2006
    lda #$12
    sta $2007
    sta $2007
    lda $0100
    sta $2000
@oam:
    lda #0
    sta $2003
    lda M_DMA_PAGE
    bne :+
    lda #2
:
    sta $4014
    rts

; The original indexed palette loop costs 479 cycles for its 32 bytes.
; Unroll it to leave enough vblank for Mario's 128-byte animation upload.
; Keep the native palette-address exit sequence and scroll restoration.
.segment "VBLANK"
FastPalette:
    jsr StreamPalette
    jmp $EBC9
; Native NMI callers restore scrolling themselves after the stream routine.
; Avoid restoring it twice when they take the ordinary palette path.
StreamPalette:
    lda #$3F
    sta $2006
    lda #0
    sta $2006
    .repeat 32,I
        lda $0390+I
        sta $2007
    .endrepeat
    ldy #$20
    lda #$3F
    sta $2006
    lda #0
    sta $2006
    sta $2006
    sta $2006
    rts

.segment "CODE"
MarioUpdate:
    lda M_MAGIC
    cmp #$4D
    beq @ready
    jsr InitMario
@ready:
    lda $16
    sta M_HELD
    eor M_PREV
    and M_HELD
    and #$40
    sta M_FIRE_EDGE
    jsr HammerSelect
    lda $0720
    sta M_PREV_Y
    jsr UpdateTimers
    lda #0
    sta M_STOMP_CHAIN
    lda M_POWER_FREEZE
    beq @move
    dec M_POWER_FREEZE
    jmp @draw
@move:
    lda $012F
    cmp #3
    bne @land
    jsr FlyingMove
    jmp @after
@land:
    lda M_HELD
    and #3
    sta M_INPUT_DIR
    jsr BodySize
    jsr DetectEnvironment
    lda M_STATE
    cmp #3
    bne :+
    jsr ClimbingMove
    jmp @after
:
    jsr CheckSupport
    lda M_STATE
    bne @directionsReady
    lda M_HELD
    and #4
    beq @directionsReady
    lda #0
    sta M_INPUT_DIR
@directionsReady:
    lda M_STATE
    bne @airCrouch
    lda M_HELD
    and #3
    bne @clearCrouch
    lda M_POWER
    beq @clearCrouch
    lda M_HELD
    and #4
    sta M_CROUCH
    jmp @airCrouch
@clearCrouch:
    lda #0
    sta M_CROUCH
@airCrouch:
    jsr BodySize
    jsr JumpInput
    lda M_STATE
    bne @input
    lda M_CROUCH
    beq @input
    lda #0
    sta M_INPUT_DIR
@input:
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
    beq @airInput
    jsr GetPlayerAnimSpeed
    lda M_INPUT_DIR
    beq @airInput
    sta M_FACING
@airInput:
    lda M_INPUT_DIR
    beq @position
@friction:
    jsr ImposeFriction
@position:
    jsr MoveX
    jsr MoveY
@after:
    jsr UpdateItem
    jsr SyncNative
@draw:
    ; Fortresses dispatch weapons through their room controller, rather
    ; than the outdoor D4A2 entry. Keep Mario's weapons active there too.
    lda $7F13
    cmp #$0B
    bne :+
    jsr Fireballs
:
    jsr MarioRender
    lda M_HELD
    sta M_PREV
    ldx #$20
    rts

InitMario:
    lda M_BANK
    pha
    lda #0
    ldx #$7F
@clear:
    sta M_MAGIC,x
    dex
    bpl @clear
    pla
    sta M_BANK
    lda #1
    sta M_FACING
    sta M_MOVING_DIR
    sta M_AREA_TYPE
    lda #3
    sta M_LIVES
    lda #8
    sta M_ENGINE_MODE
    lda #$70
    sta M_FALL_FORCE
    lda #$FF
    sta M_LAST_FRAME
    lda #$4D
    sta M_MAGIC
    lda $0130
    sta M_LAST_STAGE
    lda $A0
    sta M_LAST_WORLD
    lda $FE
    sta M_PREV_CAMERA_X
    lda $FD
    sta M_PREV_CAMERA_Y
    rts

UpdateTimers:
    lda M_STOMP_GRACE
    beq :+
    dec M_STOMP_GRACE
:
    lda M_SWIM_TIMER
    beq :+
    dec M_SWIM_TIMER
:
    lda M_CLIMB_TIMER
    beq :+
    dec M_CLIMB_TIMER
:
    lda M_BUMP_TIMER
    beq :+
    dec M_BUMP_TIMER
:
    lda M_RUNNING_TIMER
    beq :+
    dec M_RUNNING_TIMER
:
    lda M_INVINCIBLE
    beq :+
    dec M_INVINCIBLE
:
    lda M_THROW
    beq :+
    dec M_THROW
:
    lda M_STAR
    ora M_STAR_HI
    beq @stage
    lda M_STAR
    bne :+
    dec M_STAR_HI
:
    dec M_STAR
@stage:
    lda M_LAST_STAGE
    cmp $0130
    bne @resetMotion
    lda M_LAST_WORLD
    cmp $A0
    beq @camera
@resetMotion:
    lda $0130
    sta M_LAST_STAGE
    lda $A0
    sta M_LAST_WORLD
    lda #0
    sta M_SMB_X_SPEED
    sta M_SMB_X_FORCE
    sta M_SMB_X_ABS
    sta M_VY
    sta M_VY_FRAC
    sta M_STATE
    sta M_CROUCH
    sta M_ITEM_KIND
    sta M_DEAD
    sta M_BROKEN_COUNT
@camera:
    lda $FE
    sec
    sbc M_PREV_CAMERA_X
    sta M_CAMERA_DX
    lda $FD
    sec
    sbc M_PREV_CAMERA_Y
    sta M_CAMERA_DY
    lda $FE
    sta M_PREV_CAMERA_X
    lda $FD
    sta M_PREV_CAMERA_Y
    rts

BodySize:
    lda #0
    ldx M_POWER
    beq @store
    ldx M_CROUCH
    bne @store
    lda #1
@store:
    sta M_TALL
    rts

; Two feet at SMB offsets +3/+12 relative to sprite left. Kid Icarus's
; native anchor is four pixels right and 24 pixels below SMB's raw origin.
CheckSupport:
    lda M_VY
    bmi @done
    jsr FeetTiles
    bcc @platform
    pha
    lda $0720
    clc
    adc $FD
    clc
    adc #8
    and #$0F
    sta M_TMP
    pla
    cmp #$50
    bcs @snap
    lda M_TMP
    beq @ground
    bne @unsupported
@snap:
    ; A solid tile supports its top surface, never a position inside it.
    lda $0720
    sec
    sbc M_TMP
    sta $0720
    jmp @ground
@platform:
    lda $04D3
    cmp #$FF
    beq @ground
@unsupported:
    lda M_STATE
    bne @done
    lda #2
    sta M_STATE
    lda #0
    sta M_VY
    sta M_VY_FRAC
    lda M_FALL_FORCE
    sta M_GRAVITY
@done:
    rts
@ground:
    lda #0
    sta M_STATE
    sta M_VY
    sta M_VY_FRAC
    sta M_Y_FRAC
    rts
FeetTiles:
    lda $0723
    sec
    sbc #1
    tay
    lda $0720
    clc
    adc #8
    jsr TileAt
    cmp #$40
    bcs @hit
    lda $0723
    clc
    adc #8
    tay
    lda $0720
    clc
    adc #8
    jsr TileAt
    cmp #$40
@hit:
    rts

JumpInput:
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
    lda $0720
    sta M_JUMP_ORIGIN
    lda #1
    sta M_STATE
    lda #$20
    sta M_SWIM_TIMER
    lda #2
    sta $0381
@done:
    rts
JumpForce: .byte $20,$20,$1E,$28,$28,$0D,$04
FallForce: .byte $70,$70,$60,$90,$90,$0A,$09
JumpSpeed: .byte $FC,$FC,$FC,$FB,$FB,$FE,$FF

MoveX:
    lda M_SMB_X_SPEED
    jeq @done
    bmi @left
    lda #1
    bne @direction
@left:
    lda #2
@direction:
    sta M_MOVING_DIR
    lda M_SMB_X_SPEED
    asl
    asl
    asl
    asl
    clc
    adc M_X_FRAC
    sta M_X_FRAC
    lda M_SMB_X_SPEED
    php
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
    ; PLP restores the carry from the positional fractional addition.
    lda M_TMP
    adc #0
    beq @done
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
    lda $0723
    clc
    adc M_SIGN
    sta $0723
    jsr SideTiles
    bcc @next
    lda $0723
    sec
    sbc M_SIGN
    sta $0723
    lda #0
    sta M_SMB_X_SPEED
    sta M_X_FRAC
    rts
@next:
    dec M_STEPS
    bne @step
@done:
    rts

SideTiles:
    lda #9
    ldy M_SIGN
    bpl :+
    lda #$FE
:
    clc
    adc $0723
    sta M_TMP
    tay
    lda $0720
    clc
    adc #7
    jsr TileAt
    cmp #$50
    bcs @done
    lda M_TALL
    beq @small
    ldy M_TMP
    lda $0720
    sec
    sbc #8
    jsr TileAt
    cmp #$50
    bcs @done
    ldy M_TMP
    lda $0720
    sec
    sbc #20
    jmp @probe
@small:
    ldy M_TMP
    lda $0720
    sec
    sbc #6
@probe:
    jsr TileAt
    cmp #$50
@done:
    rts

MoveY:
    lda M_STATE
    jeq @done
    lda M_VY
    bpl @fall
    lda M_HELD
    and #$80
    and M_PREV
    bne @position
    lda M_JUMP_ORIGIN
    sec
    sbc $0720
    cmp #1
    bcc @position
@fall:
    lda M_FALL_FORCE
    sta M_GRAVITY
@position:
    lda M_SWIMMING
    beq @integrate
    lda $0720
    cmp #44
    bcs @integrate
    lda #$18
    sta M_GRAVITY
@integrate:
    lda M_Y_FRAC
    clc
    adc M_VY_FRAC
    sta M_Y_FRAC
    lda M_VY
    adc #0
    beq @gravity
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
    lda M_SIGN
    bmi @up
    inc $0720
    jsr FeetTiles
    bcc @next
    ; Native one-way platforms land only when a top boundary is crossed.
    lda $0720
    clc
    adc $FD
    clc
    adc #8
    and #$0F
    cmp #1
    bcs @next
    lda #0
    sta M_STATE
    sta M_VY
    sta M_VY_FRAC
    sta M_Y_FRAC
    rts
@up:
    dec $0720
    jsr HeadTile
    cmp #$50
    bcc @next
    jsr HitBlock
    bcc @next
    inc $0720
    lda #1
    sta M_VY
    lda #0
    sta M_VY_FRAC
    jmp @gravity
@next:
    dec M_STEPS
    bne @step
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
@done:
    rts
HeadTile:
    lda $0723
    clc
    adc #4
    tay
    lda M_TALL
    beq @small
    lda $0720
    sec
    sbc #20
    jmp TileAt
@small:
    lda $0720
    sec
    sbc #6
    jmp TileAt

SyncNative:
    lda M_SMB_X_SPEED
    sta $1C
    lda M_VY
    sta $1D
    lda #0
    ldx M_STATE
    beq :+
    lda #$80
:
    sta $1E
    rts

FlyingMove:
    ; Kid Icarus's final auto-scrolling flight remains a required stage ability.
    lda #2
    sta M_POWER
    lda M_HELD
    and #3
    beq @vertical
    sta M_FACING
    and #1
    beq @left
    inc $0723
    jmp @vertical
@left:
    dec $0723
@vertical:
    lda M_HELD
    and #8
    beq @down
    dec $0720
@down:
    lda M_HELD
    and #4
    beq @done
    inc $0720
@done:
    rts

.include "smb-land.inc"

InstallAssets:
    lda #$F8
    sta $0244
    sta $0248
    sta $024C
    lda #0
    sta M_EXTRA_PALETTE_ACTIVE
    sta M_PENDING_ATTR
    sta M_VRAM_NEXT
    lda #$FF
    sta M_PREP_CELL
    sta M_PREP_PAGE
    sta M_DRAW_CELL
    sta M_DRAW_PAGE
    bit $2002
    lda #0
    sta $2006
    lda #$80
    sta $2006
    ldx #0
@first:
    lda ItemChr,x
    sta $2007
    inx
    bne @first
    ldx #0
@last:
    lda ItemChr+$100,x
    sta $2007
    inx
    cpx #128
    bcc @last
    lda #$FF
    sta M_LAST_FRAME
    sta M_DISPLAY_PENDING
    lda #1
    sta M_ASSETS_READY
    rts
PrepareDisplay:
    lda M_MAGIC
    cmp #$4D
    beq :+
    jsr InitMario
:
    jsr BodySize
    jsr ResolveSpawnSides
    lda M_STATE
    bne :+
    jsr CheckSupport
:
    jsr MarioRender
    jsr ComposeOam
    lda $0100
    and #$FB
    sta $2000
    bit $2002
    lda #0
    sta $2006
    sta $2006
    ldx #0
@pose:
    lda M_SPRITES,x
    sta $2007
    inx
    bpl @pose
    lda #0
    sta M_DIRTY
    sta M_DISPLAY_PENDING
    lda $0100
    sta $2000
    rts

; Pit's native start X can put Mario's wider hitbox into the room wall.
; Align a new spawn with the nearest clear side before the first jump.
ResolveSpawnSides:
    lda #16
    sta M_STEPS
@check:
    lda #$FF
    sta M_SIGN
    jsr SideTiles
    bcc @right
    lda #1
    sta M_SIGN
    jsr SideTiles
    bcs @done
    inc $0723
    jmp @next
@right:
    lda #1
    sta M_SIGN
    jsr SideTiles
    bcc @done
    dec $0723
@next:
    dec M_STEPS
    bne @check
@done:
    rts

MarioRender:
    lda M_MAGIC
    cmp #$4D
    beq :+
    jsr InitMario
:
    jsr SelectFrame
    sta M_FRAME
    cmp M_LAST_FRAME
    beq @oam
    sta M_LAST_FRAME
    lda #0
    sta M_DIRTY
    lda #<MarioFrames
    sta $00
    lda #>MarioFrames
    sta $01
    lda M_FRAME
    lsr
    pha
    lda #0
    ror
    clc
    adc $00
    sta $00
    pla
    adc $01
    sta $01
    ldy #0
@buffer:
    lda ($00),y
    sta M_SPRITES,y
    iny
    bpl @buffer
    lda #1
    sta M_DIRTY
@oam:
    lda M_INVINCIBLE
    beq @visible
    lda $14
    and #1
    bne @hide
@visible:
    ldx #0
    lda M_FACING
    and #2
    beq @rows
    ldx #$40
@rows:
    stx M_TMP
    txa
    asl
    rol
    rol
    and #1
    sta M_TILE
    ldy #0
@sprite:
    lda MarioOam,y
    tax
    tya
    and #$FE
    asl
    asl
    clc
    adc $0720
    sec
    sbc #24
    sta M_PLAYER_OAM,x
    tya
    sta M_PLAYER_OAM+1,x
    lda M_TMP
    sta M_PLAYER_OAM+2,x
    tya
    eor M_TILE
    and #1
    asl
    asl
    asl
    clc
    adc $0723
    sec
    sbc #4
    sta M_PLAYER_OAM+3,x
    iny
    cpy #8
    bcc @sprite
    jsr MarioPalette
    ldx #$20
    rts
@hide:
    ldy #7
@hideLoop:
    ldx MarioOam,y
    lda #$F8
    sta M_PLAYER_OAM,x
    dey
    bpl @hideLoop
    ldx #$20
    rts
MarioOam: .byte $00,$04,$08,$0C,$10,$14,$18,$1C

SelectFrame:
    lda $0721
    and #$40
    jne @dead
    lda M_POWER_FREEZE
    beq @environment
    jmp MorphFrame
@environment:
    lda M_STATE
    cmp #3
    beq @climbing
    lda M_SWIMMING
    beq @size
    jsr Animate
    clc
    adc #5
    ldx M_POWER
    bne @return
    clc
    adc #12
@return:
    rts
@climbing:
    jsr Animate
    and #1
    clc
    adc #8
    ldx M_POWER
    bne @return
    clc
    adc #12
    rts
@size:
    lda M_POWER
    beq @small
    lda M_CROUCH
    bne @crouch
    lda M_THROW
    bne @throw
    lda M_STATE
    bne @bigJump
    lda M_SMB_X_SPEED
    beq @bigStand
    lda M_INPUT_DIR
    beq @bigWalk
    cmp M_MOVING_DIR
    beq @bigWalk
    lda #3
    rts
@bigWalk:
    jsr Animate
    rts
@bigStand:
    lda #24
    rts
@bigJump:
    lda #4
    rts
@crouch:
    lda #10
    rts
@throw:
    lda #11
    rts
@small:
    lda M_STATE
    bne @smallJump
    lda M_SMB_X_SPEED
    beq @smallStand
    lda M_INPUT_DIR
    beq @smallWalk
    cmp M_MOVING_DIR
    beq @smallWalk
    lda #15
    rts
@smallWalk:
    jsr Animate
    clc
    adc #12
    rts
@smallStand:
    lda #23
    rts
@smallJump:
    lda #16
    rts
@dead:
    lda #22
    rts
Animate:
    lda M_ANIM_TIMER
    beq @advance
    dec M_ANIM_TIMER
    lda M_ANIM
    rts
@advance:
    lda M_ANIM_SET
    sta M_ANIM_TIMER
    inc M_ANIM
    lda M_ANIM
    cmp #3
    bcc @done
    lda #0
    sta M_ANIM
@done:
    rts
MarioPalette:
    ldy #0
    lda M_POWER
    cmp #2
    bne :+
    ldy #3
:
    lda M_STAR
    ora M_STAR_HI
    bne @cycle
    lda M_POWER_FREEZE
    beq @palette
    lda M_TRANSFORM
    cmp #2
    bne @palette
@cycle:
    lda $14
    lsr
    lsr
    and #3
    sta M_TMP
    asl
    clc
    adc M_TMP
    adc #6
    tay
@palette:
    lda MarioPalettes,y
    sta $03A1
    lda MarioPalettes+1,y
    sta $03A2
    lda MarioPalettes+2,y
    sta $03A3
    jsr LifeHud
    jmp ExtraPalette
LifeHud:
    lda $A0
    cmp #2
    bcc @done
    cmp #9
    bcs @done
    ldy #0
@icon:
    ldx LifeOam,y
    tya
    lsr
    asl
    asl
    asl
    clc
    adc #12
    sta $0200,x
    tya
    clc
    adc #28
    sta $0201,x
    lda #0
    sta $0202,x
    tya
    and #1
    asl
    asl
    asl
    clc
    adc #80
    sta $0203,x
    iny
    cpy #4
    bcc @icon
    lda M_LIVES
    ldy #0
@tens:
    cmp #10
    bcc @digits
    sec
    sbc #10
    iny
    bne @tens
@digits:
    clc
    adc #$60
    sta $0241
    tya
    clc
    adc #$60
    sta $021D
    lda #16
    sta $021C
    sta $0240
    lda #104
    sta $021F
    lda #112
    sta $0243
    lda #1
    sta $021E
    sta $0242
@done:
    rts
LifeOam: .byte $0C,$10,$14,$18
ExtraPalette:
    lda $0739
    ora $073D
    bmi @active
    lda M_ITEM_KIND
    bne @active
    lda M_EXTRA_PALETTE_ACTIVE
    beq @done
    lda M_NATIVE_EXTRA_PALETTE
    sta $03AD
    lda M_NATIVE_EXTRA_PALETTE+1
    sta $03AE
    lda M_NATIVE_EXTRA_PALETTE+2
    sta $03AF
    lda #0
    sta M_EXTRA_PALETTE_ACTIVE
    rts
@active:
    lda M_EXTRA_PALETTE_ACTIVE
    bne @set
    inc M_EXTRA_PALETTE_ACTIVE
    lda $03AD
    sta M_NATIVE_EXTRA_PALETTE
    lda $03AE
    sta M_NATIVE_EXTRA_PALETTE+1
    lda $03AF
    sta M_NATIVE_EXTRA_PALETTE+2
@set:
    ldy #0
    lda M_ITEM_KIND
    cmp #4
    bne :+
    ldy #3
:
    lda ExtraPalettes,y
    sta $03AD
    lda ExtraPalettes+1,y
    sta $03AE
    lda ExtraPalettes+2,y
    sta $03AF
@done:
    rts
MarioPalettes:
    .byte $16,$27,$18, $37,$27,$16
    .byte $16,$27,$18, $1A,$30,$27, $16,$30,$27, $0F,$36,$17
ExtraPalettes:
    .byte $16,$30,$27, $1A,$30,$27

HammerSelect:
    lda M_HELD
    eor M_PREV
    and M_HELD
    and #$20
    beq @done
    lda $3C
    bne @putAway
    lda $014F
    beq @done
    lda #1
    bne @equip
@putAway:
    lda #0
@equip:
    sta $3C
    lda #0
    sta $073A
    sta M_FIRE_LIFE
    sta M_FIRE_LIFE+1
    jsr $EC68
@done:
    rts
HammerUpdate:
    lda M_FIRE_EDGE
    beq @draw
    lda $073A
    bne @draw
    lda $014F
    beq @draw
    lda #8
    sta $073A
    sta M_THROW
    lda #$10
    sta $0380
@draw:
    ; Reuse the original mallet's sprite and hit timing, with Mario facing.
    ; $3C and the $0738 weapon slot keep native enemies/statues compatible.
    lda $1C
    pha
    lda #0
    ldx M_FACING
    cpx #2
    bne :+
    lda #$FF
:
    sta $1C
    jsr $D5F4
    pla
    sta $1C
    lda $7F13
    cmp #$0B
    bne :+
    jsr FortressHammerTerrain
:
    rts

Fireballs:
    lda $3C
    beq @fire
    jsr HammerUpdate
    ldx #$20
    rts
@fire:
    lda M_FIRE_EDGE
    beq @update
    lda M_POWER
    cmp #2
    bne @update
    lda M_CROUCH
    bne @update
    lda M_FIRE_COUNTER
    and #1
    asl
    asl
    clc
    adc #$38
    tax
    lda $0701,x
    bmi @update
@spawn:
    inc M_FIRE_COUNTER
    lda M_FACING
    and #1
    beq @left
    lda #$8C
    bne @flags
@left:
    lda #$84
@flags:
    sta $0701,x
    lda $0723
    sta $0703,x
    lda $0720
    sec
    sbc #24
    sta $0700,x
    txa
    lsr
    lsr
    and #1
    tay
    lda #4
    sta M_FIRE_VY,y
    lda #0
    sta M_FIRE_FRAC,y
    sta M_FIRE_POS_FRAC,y
    sta M_FIRE_BOUNCE,y
    lda #100
    sta M_FIRE_LIFE,y
    lda #8
    sta M_THROW
    lda #$10
    sta $0380
@update:
    ldx #$38
    ldy #0
    jsr FireOne
    ldx #$3C
    ldy #1
    jsr FireOne
    ldx #$20
    rts
FireOne:
    sty M_SWAP_GUARD
    lda $0701,x
    jpl @hide
    lda $0700,x
    cmp #$F0
    jcs @remove
    lda M_FIRE_LIFE,y
    jeq @remove
    sec
    sbc #1
    sta M_FIRE_LIFE,y
    lda $0703,x
    sec
    sbc M_CAMERA_DX
    sta $0703,x
    lda $0700,x
    sec
    sbc M_CAMERA_DY
    sta $0700,x
    lda #4
    sta M_STEPS
@horizontal:
    lda $0701,x
    and #8
    beq @stepLeft
    lda $0703,x
    clc
    adc #1
    jcs @remove
    jmp @move
@stepLeft:
    lda $0703,x
    sec
    sbc #1
    jcc @remove
@move:
    sta $0703,x
    tay
    lda $0700,x
    jsr TileAt
    cmp #$50
    jcs @remove
    dec M_STEPS
    bne @horizontal
    ldy M_SWAP_GUARD
    lda M_FIRE_POS_FRAC,y
    clc
    adc M_FIRE_FRAC,y
    sta M_FIRE_POS_FRAC,y
    lda M_FIRE_VY,y
    adc #0
    clc
    adc $0700,x
    sta $0700,x
    lda M_FIRE_FRAC,y
    clc
    adc #$50
    sta M_FIRE_FRAC,y
    lda M_FIRE_VY,y
    adc #0
    sta M_FIRE_VY,y
    bmi @probe
    cmp #3
    bcc @probe
    lda M_FIRE_FRAC,y
    cmp #$80
    bcc @probe
    lda #3
    sta M_FIRE_VY,y
    lda #0
    sta M_FIRE_FRAC,y
@probe:
    lda $0700,x
    clc
    adc #7
    ldy $0703,x
    jsr TileAt
    cmp #$40
    bcc @noBounce
    ldy M_SWAP_GUARD
    lda M_FIRE_VY,y
    bmi @remove
    lda M_FIRE_BOUNCE,y
    bne @remove
    lda #1
    sta M_FIRE_BOUNCE,y
    lda #$FD
    sta M_FIRE_VY,y
    lda $0700,x
    clc
    adc $FD
    and #$F8
    sec
    sbc $FD
    sta $0700,x
    jmp @draw
@noBounce:
    ldy M_SWAP_GUARD
    lda #0
    sta M_FIRE_BOUNCE,y
@draw:
    lda $0700,x
    sta $0200,x
    lda $0703,x
    sta $0203,x
    lda $14
    lsr
    lsr
    and #1
    clc
    adc #24
    sta $0201,x
    lda #3
    sta $0202,x
    rts
@remove:
    lda #0
    sta $0701,x
@hide:
    lda #$F8
    sta $0200,x
    sta $0700,x
    rts

TryStomp:
    jsr CanStomp
    bcs @no
    lda M_STAR
    ora M_STAR_HI
    bne @hit
    lda #1
    sta M_STOMP_CHAIN
    lda #16
    sta M_STOMP_GRACE
    lda #$FC
    sta M_VY
    sta $1D
    lda #0
    sta M_VY_FRAC
    sta M_Y_FRAC
    lda #1
    sta M_STATE
    lda #2
    sta $0380
@hit:
    clc
    rts
@no:
    sec
    rts
CanStomp:
    ; Transformed enemies are collectible mallets, not attack targets.
    lda $0701,x
    and #$F8
    cmp #$70
    beq @no
    cpx #$F0
    bcs :+
    lda $3E
    bne @no
:
    lda M_STAR
    ora M_STAR_HI
    bne @star
    lda M_STATE
    beq @no
    lda M_VY
    bpl @descending
    ; Native enemies are checked separately. Retain the landing for the
    ; rest of this update after the first enemy has already bounced Mario.
    lda M_STOMP_CHAIN
    beq @no
@descending:
    jsr StompX
    bcs @no
    lda M_PREV_Y
    clc
    adc #16
    sec
    sbc $0700,x
    ; Allow a moving enemy's head to meet the edge of Mario's feet.
    cmp #9
    bcc @current
    cmp #$E0
    bcc @no
@current:
    lda $0720
    clc
    adc #16
    sec
    sbc $0700,x
    cmp #16
    bcc @yes
    cmp #$FE
    bcc @no
@yes:
    clc
    rts
@star:
    jsr ContactX
    bcs @no
    jsr ContactY
    bcs @no
    clc
    rts
@no:
    sec
    rts
ContactX:
    lda $0723
    sec
    sbc $0703,x
    bpl :+
    eor #$FF
    clc
    adc #1
:
    cmp #12
    rts
StompX:
    jsr ContactX
    cmp #16
    rts
ContactY:
    lda $0720
    clc
    adc #8
    sec
    sbc $0700,x
    clc
    adc #8
    ldy M_TALL
    beq @small
    cmp #36
    rts
@small:
    cmp #22
    rts
MarioContact:
    lda $A2
    jmi @no
    lda $0721
    and #$40
    jne @no
    ; Resolve a landing before the narrower native body-contact box.
    jsr CanStomp
    bcs @body
    lda #16
    sta M_STOMP_GRACE
    jmp @no
@body:
    jsr ContactX
    jcs @no
    jsr ContactY
    jcs @no
    cpx #$F0
    bcs @stomp
    lda $3E
    beq @stomp
    ; Preserve native mallet conversion: these falling objects are pickups.
    lda #0
    sta $0701,x
    lda #$F8
    sta $0700,x
    sta $0200,x
    sta $0204,x
    sta $0208,x
    sta $020C,x
    lda $014F
    cmp #99
    bcs :+
    inc $014F
:
    lda #$10
    sta $0381
    lda #0
    clc
    rts
@stomp:
    jsr CanStomp
    bcc @no
@damage:
    lda M_STOMP_GRACE
    ora M_INVINCIBLE
    ora M_STAR
    ora M_STAR_HI
    bne @no
    lda M_POWER
    beq @die
    lda #0
    sta M_POWER
    lda #1
    sta M_TRANSFORM
    lda #$A8
    sta M_INVINCIBLE
    sta $0728
    lda #40
    sta M_POWER_FREEZE
    lda #$80
    sta $0380
    lda #0
    sec
    rts
@die:
    jsr NativeDeath
    lda #0
    sec
    rts
@no:
    lda #$FF
    sec
    rts
CommonDamage:
    lda M_STOMP_GRACE
    ora M_INVINCIBLE
    ora M_STAR
    ora M_STAR_HI
    bne @protect
    lda M_POWER
    beq @small
    lda #0
    sta M_POWER
    lda #1
    sta M_TRANSFORM
    lda #$A8
    sta M_INVINCIBLE
    lda #40
    sta M_POWER_FREEZE
@protect:
    lda #15
    sta $A6
    rts
@small:
    lda #0
    sta $A6
    rts

DeathMove:
    lda M_DEAD
    bne @step
    inc M_DEAD
    lda #$FC
    sta M_VY
    lda #0
    sta M_VY_FRAC
    sta M_POWER
    sta M_STAR
    sta M_STAR_HI
    sta M_INVINCIBLE
    lda $0720
    cmp #$E8
    bcs @over
@step:
    inc M_DEAD
    lda M_DEAD
    cmp #24
    bcc @draw
    lda M_Y_FRAC
    clc
    adc M_VY_FRAC
    sta M_Y_FRAC
    lda $0720
    adc M_VY
    sta $0720
    lda M_VY_FRAC
    clc
    adc #$28
    sta M_VY_FRAC
    lda M_VY
    adc #0
    sta M_VY
    bmi @draw
    lda $0720
    cmp #$E8
    bcc @draw
@over:
    lda #$40
    sta $AB
@draw:
    jsr MarioRender
    rts

HitBlock:
    lda $00
    sta M_BLOCK_LO
    lda $01
    sta M_BLOCK_HI
    lda M_PROBE_X
    sta M_BLOCK_X
    lda M_PROBE_Y
    sta M_BLOCK_Y
    lda M_BUMP_TIMER
    jne @solid
    lda M_TILE
    cmp #$59
    bne @solid
    lda M_POWER
    beq @bump
    ; Native levels and their metatiles are copied into cartridge RAM. Remove
    ; a real brick there, and queue the same four background pixels for NMI.
    ldy #0
    lda #0
    sta ($00),y
    jsr QueueErase
    lda #$FE
    sta M_VY
    lda #$80
    sta $0380
    lda #16
    sta M_BUMP_TIMER
    clc
    rts
@bump:
    lda #16
    sta M_BUMP_TIMER
    ; $0380 bit 0 stops all native audio. Bit 3 is Kid Icarus's
    ; wall-bump effect and leaves the current music playing.
    lda #$08
    sta $0380
@solid:
    sec
    rts
QueueErase:
    ldx #0
    lda M_BLOCK_Y
    clc
    adc $FD
    bcc @noCarry
    adc #15
    inx
    jmp @row
@noCarry:
    cmp #240
    bcc @row
    sec
    sbc #240
    inx
@row:
    and #$F0
    sta M_TMP
    lda #0
    sta M_ERASE_HI
    lda M_TMP
    asl
    rol M_ERASE_HI
    asl
    rol M_ERASE_HI
    sta M_ERASE_LO
    lda $1A
    eor #$FF
    stx M_TILE
    eor M_TILE
    and #1
    asl
    asl
    asl
    ora #$20
    ora M_ERASE_HI
    sta M_ERASE_HI
    lda M_BLOCK_X
    clc
    adc $FE
    pha
    lda $1B
    adc #0
    and #1
    asl
    asl
    ora M_ERASE_HI
    sta M_ERASE_HI
    pla
    and #$F0
    lsr
    lsr
    lsr
    ora M_ERASE_LO
    sta M_ERASE_LO
    lda #1
    sta M_ERASE_PENDING
    rts
SpawnItem:
    lda M_ITEM_KIND
    bne @done
    lda M_POWER_TYPE
    and #3
    clc
    adc #1
    cmp #2
    bne :+
    ldx M_POWER
    bne :+
    lda #1
:
    sta M_ITEM_KIND
    inc M_POWER_TYPE
    lda M_BLOCK_X
    and #$F0
    sta M_ITEM_X
    lda M_BLOCK_Y
    and #$F0
    sec
    sbc #16
    sta M_ITEM_Y
    lda #$F0
    sta M_ITEM_TIMER
    lda #0
    sta M_ITEM_VY
    sta M_ITEM_VFRAC
    sta M_ITEM_POS_FRAC
    lda #1
    sta M_ITEM_DIRECTION
    lda #16
    sta M_ITEM_EMERGE
@done:
    rts
HeartBonus:
    lda M_INPUT_A
    cmp #5
    bcs @ten
    cmp #3
    bcs @five
    lda #1
    bne @add
@five:
    lda #5
    bne @add
@ten:
    lda #10
@add:
    clc
    adc M_COIN_COUNT
    sta M_COIN_COUNT
    lda M_COIN_COUNT
    cmp #100
    bcc @power
    sec
    sbc #100
    sta M_COIN_COUNT
    inc M_LIVES
@power:
    lda M_POWER
    cmp #2
    bcs @done
    tax
    lda #0
    cpx #0
    beq :+
    lda #2
:
    sta M_TRANSFORM
    inc M_POWER
    lda #40
    sta M_POWER_FREEZE
    lda #$40
    sta $0380
    rts
@done:
    rts
LoseLife:
    lda M_MAGIC
    cmp #$4D
    bne @gameOver
    lda M_LIVES
    beq @gameOver
    dec M_LIVES
    beq @gameOver
    lda #0
    sta M_POWER
    sta M_STATE
    sta M_DEAD
    sta M_INVINCIBLE
    sta M_STAR
    sta M_STAR_HI
    sta M_STOMP_GRACE
    sta M_STOMP_CHAIN
    sta M_ITEM_KIND
    sta M_SMB_X_SPEED
    sta M_SMB_X_FORCE
    sta M_SMB_X_ABS
    sta M_VY
    sta M_VY_FRAC
    sta M_CROUCH
    sta $37
    sta $38
    sta $AB
    lda #15
    sta $A6
    clc
    rts
@gameOver:
    lda #0
    sta M_MAGIC
    sec
    rts
UpdateItem:
    lda M_ITEM_KIND
    jeq @hide
    dec M_ITEM_TIMER
    jeq @clear
    lda $012F
    cmp #3
    bne @cameraReady
    lda M_ITEM_X
    sec
    sbc M_CAMERA_DX
    sta M_ITEM_X
    lda M_ITEM_Y
    sec
    sbc M_CAMERA_DY
    sta M_ITEM_Y
@cameraReady:
    lda M_ITEM_EMERGE
    beq @physics
    dec M_ITEM_EMERGE
    jmp @draw
@physics:
    jsr ItemMovement
@contact:
    lda M_ITEM_X
    sec
    sbc $0723
    bpl :+
    eor #$FF
    clc
    adc #1
:
    cmp #14
    bcs @draw
    lda M_ITEM_Y
    sec
    sbc $0720
    clc
    adc #20
    cmp #32
    bcs @draw
    lda M_ITEM_KIND
    cmp #3
    beq @star
    cmp #4
    beq @oneup
    cmp #1
    beq @mushroom
    lda M_POWER
    beq @mushroom
    lda #2
    jmp @setPower
@mushroom:
    lda M_POWER
    cmp #2
    beq @clear
    cmp #1
    bne :+
    lda #2
    bne @setPower
:
    lda #1
@setPower:
    sta M_POWER
    cmp #2
    lda #0
    bcc :+
    lda #2
:
    sta M_TRANSFORM
@grow:
    lda #40
    sta M_POWER_FREEZE
    lda #$40
    sta $0380
    jmp @clear
@star:
    lda #2
    sta M_STAR_HI
    lda #$DF
    sta M_STAR
    jmp @clear
@oneup:
    inc M_LIVES
    lda #1
    sta $0381
@clear:
    lda #0
    sta M_ITEM_KIND
@hide:
    lda #$F8
    sta M_ITEM_OAM
    sta M_ITEM_OAM+4
    sta M_ITEM_OAM+8
    sta M_ITEM_OAM+12
    rts
@draw:
    lda M_ITEM_KIND
    asl
    asl
    clc
    adc #4
    sta M_TMP
    ldy #0
@sprite:
    ldx ItemOam,y
    lda M_ITEM_Y
    cpy #2
    bcc :+
    clc
    adc #8
:
    sta M_ITEM_OAM,x
    tya
    clc
    adc M_TMP
    sta M_ITEM_OAM+1,x
    lda #3
    sta M_ITEM_OAM+2,x
    tya
    and #1
    asl
    asl
    asl
    clc
    adc M_ITEM_X
    sta M_ITEM_OAM+3,x
    iny
    cpy #4
    bcc @sprite
    rts
ItemOam: .byte $00,$04,$08,$0C
ItemMovement:
    lda M_ITEM_KIND
    cmp #2
    jeq @done
    lda M_ITEM_X
    clc
    adc M_ITEM_DIRECTION
    sta M_ITEM_X
    clc
    adc #8
    tay
    lda M_ITEM_Y
    clc
    adc #8
    jsr TileAt
    cmp #$50
    bcc @vertical
    lda M_ITEM_DIRECTION
    eor #$FE
    sta M_ITEM_DIRECTION
@vertical:
    lda M_ITEM_POS_FRAC
    clc
    adc M_ITEM_VFRAC
    sta M_ITEM_POS_FRAC
    lda M_ITEM_Y
    adc M_ITEM_VY
    sta M_ITEM_Y
    lda M_ITEM_VFRAC
    clc
    adc #$20
    sta M_ITEM_VFRAC
    lda M_ITEM_VY
    adc #0
    sta M_ITEM_VY
    bmi @done
    lda M_ITEM_X
    clc
    adc #8
    tay
    lda M_ITEM_Y
    clc
    adc #16
    jsr TileAt
    cmp #$40
    bcc @done
    lda #0
    sta M_ITEM_VY
    sta M_ITEM_VFRAC
    sta M_ITEM_POS_FRAC
    lda M_ITEM_Y
    clc
    adc $FD
    and #$F0
    sec
    sbc $FD
    sta M_ITEM_Y
    lda M_ITEM_KIND
    cmp #3
    bne @done
    lda #$FC
    sta M_ITEM_VY
@done:
    rts

.include "sprites.inc"
.include "terrain.inc"
.include "environment.inc"
.include "morph.inc"
.include "scroll.inc"

.segment "ASSETS"
MarioFrames: .incbin "../build/mario-frames.chr"
ItemChr: .incbin "../build/items.chr"

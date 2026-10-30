; Stock Kid Icarus has no SMB vines or swimming areas. These two formerly
; unused non-solid metatiles make both original SMB movement modes available
; to level edits without changing existing lava, columns, or platforms:
; $3E = water, $3F = vine. A forced mode is reserved for differential tests.
DetectEnvironment:
    lda M_FORCED_ENV
    bne @forced
    lda $0723
    clc
    adc #4
    tay
    lda $0720
    sec
    sbc #4
    jsr TileAt
    cmp #$3E
    beq @water
    cmp #$3F
    beq @vine
    lda M_STATE
    cmp #3
    bne :+
    lda #2
    sta M_STATE
    lda #0
    sta M_VY
    sta M_VY_FRAC
:
    lda #0
    beq @store
@forced:
    cmp #1
    beq @water
    jmp @vine
@water:
    lda M_SWIMMING
    bne @wet
    lda #$0A
    sta M_FALL_FORCE
@wet:
    lda #1
    bne @store
@vine:
    lda M_STATE
    cmp #3
    beq @dry
    lda M_HELD
    and #8
    beq @dry
    lda #3
    sta M_STATE
    lda #0
    sta M_SMB_X_SPEED
    sta M_SMB_X_FORCE
    sta M_SMB_X_ABS
    sta M_CLIMB_TIMER
    sta M_CROUCH
@dry:
    lda #0
@store:
    sta M_SWIMMING
    eor #1
    sta M_AREA_TYPE
    rts

ClimbingMove:
    lda M_HELD
    and #$80
    and M_PREV
    bne @climb
    lda M_HELD
    and #$80
    beq @climb
    lda M_INPUT_DIR
    beq @climb
    lda #0
    sta M_STATE
    jsr JumpInput
    lda #$18
    ldx M_INPUT_DIR
    cpx #1
    beq :+
    lda #$E8
:
    sta M_SMB_X_SPEED
    jsr MoveX
    jmp MoveY
@climb:
    ldy #0
    lda M_HELD
    and #$0C
    beq @force
    iny
    and #8
    bne @force
    iny
@force:
    lda ClimbForce,y
    sta M_VY_FRAC
    lda ClimbSpeed,y
    sta M_VY
    lda #8
    ldx M_VY
    bmi :+
    lsr
:
    sta M_ANIM_SET
    lda M_Y_FRAC
    clc
    adc M_VY_FRAC
    sta M_Y_FRAC
    lda $0720
    adc M_VY
    sta $0720
    lda M_INPUT_DIR
    beq @resetTimer
    ldy M_CLIMB_TIMER
    bne @done
    ldy #24
    sty M_CLIMB_TIMER
    ldx #0
    ldy M_FACING
    lsr
    bcs :+
    inx
    inx
:
    dey
    beq :+
    inx
:
    lda $0723
    clc
    adc ClimbXAdder,x
    sta $0723
    lda M_INPUT_DIR
    eor #3
    sta M_FACING
    rts
@resetTimer:
    sta M_CLIMB_TIMER
@done:
    rts
ClimbSpeed: .byte $00,$FF,$01
ClimbForce: .byte $00,$20,$FF
ClimbXAdder: .byte $0E,$04,$FC,$F2

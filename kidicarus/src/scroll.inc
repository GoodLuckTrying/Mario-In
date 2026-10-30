.segment "SCROLL"
; Keep native one-pixel camera bounds, screen transitions and spawning, while
; consuming all Mario movement up to four pixels. Native actors add/subtract
; $27, so they receive the full camera delta exactly once.
ScrollBridge:
    lda $7F13
    cmp #$94
    beq @vertical
    cmp #$2B
    beq @vertical
    cmp #$E1
    beq @horizontal
    jmp $7F0C
@vertical:
    lda #0
    beq @mode
@horizontal:
    lda #1
@mode:
    sta M_SCROLL_MODE
    lda #0
    sta M_SCROLL_COUNT
    sta M_CAMERA_DX
    sta M_CAMERA_DY
@step:
    lda #0
    sta $27
    ldx #$20
    jsr $7F0C
    lda $27
    beq @done
    inc M_SCROLL_COUNT
    lda $37
    ora $38
    bne @done
    lda M_SCROLL_COUNT
    cmp #4
    bcc @step
@done:
    lda M_SCROLL_COUNT
    sta $27
    jeq @prepare
    ldx M_SCROLL_MODE
    jeq @shiftY
    sta M_CAMERA_DX
    lda M_ITEM_X
    sec
    sbc M_SCROLL_COUNT
    sta M_ITEM_X
    .repeat 8,I
        lda M_PLAYER_OAM+3+I*4
        sec
        sbc M_SCROLL_COUNT
        sta M_PLAYER_OAM+3+I*4
    .endrepeat
    .repeat 4,I
        lda ItemScrollOam+I
        tax
        lda M_ITEM_OAM+3,x
        sec
        sbc M_SCROLL_COUNT
        sta M_ITEM_OAM+3,x
    .endrepeat
    jmp @prepare
@shiftY:
    pha
    clc
    adc M_PREV_Y
    sta M_PREV_Y
    pla
    eor #$FF
    clc
    adc #1
    sta M_CAMERA_DY
    lda M_ITEM_Y
    clc
    adc M_SCROLL_COUNT
    sta M_ITEM_Y
    ldy #7
@playerY:
    ldx PlayerScrollOam,y
    lda M_PLAYER_OAM,x
    cmp #$F0
    bcs :+
    clc
    adc M_SCROLL_COUNT
    sta M_PLAYER_OAM,x
:
    dey
    bpl @playerY
    ldy #3
@itemY:
    ldx ItemScrollOam,y
    lda M_ITEM_OAM,x
    cmp #$F0
    bcs :+
    clc
    adc M_SCROLL_COUNT
    sta M_ITEM_OAM,x
:
    dey
    bpl @itemY
@prepare:
    jsr PrepareStream
    jsr ForecastStream
    ldx #$20
    rts
PlayerScrollOam: .byte $00,$04,$08,$0C,$10,$14,$18,$1C
ItemScrollOam: .byte $00,$04,$08,$0C

PrepareStream:
    lda $5C
    bmi @invalidate
    jsr StreamCell
    cmp M_PREP_CELL
    bne @new
    cpy M_PREP_PAGE
    beq @done
@new:
    sta M_PREP_CELL
    sty M_PREP_PAGE
    lda M_SCROLL_MODE
    beq @vertical
    jsr $AC7B
    jmp $AD2A
@vertical:
    lda $7F13
    cmp #$2B
    beq @sky
    jsr $956D
    jmp $963E
@sky:
    jsr $9804
    jmp $98D5
@invalidate:
    lda #$FF
    sta M_PREP_CELL
@done:
    rts
StreamCell:
    lda M_SCROLL_MODE
    beq @vertical
    ldy $1B
    lda $FE
    and #$F0
    rts
@vertical:
    ldy $1A
    lda $FD
    and #$F0
    rts
ForecastStream:
    lda M_PENDING_ATTR
    bne @busy
    jsr StreamCell
    cmp M_PREP_CELL
    bne @idle
    cpy M_PREP_PAGE
    bne @idle
    cmp M_DRAW_CELL
    bne @phase
    cpy M_DRAW_PAGE
    beq @idle
@phase:
    lda M_SCROLL_MODE
    beq @vertical
    lda $FE
    and #$0F
    cmp #2
    bcc @idle
    bcs @busy
@vertical:
    lda $FD
    and #$0F
    cmp #14
    bcs @idle
@busy:
    lda #1
    bne @store
@idle:
    lda #0
@store:
    sta M_VRAM_NEXT
    rts
HorizontalStream:
    lda M_PENDING_ATTR
    beq @tiles
    lda #0
    sta M_PENDING_ATTR
    jmp $AC47
@tiles:
    jsr ForecastStream
    lda M_VRAM_NEXT
    beq @normal
    jsr StreamCell
    sta M_DRAW_CELL
    sty M_DRAW_PAGE
    lda #1
    sta M_PENDING_ATTR
    jmp $ABF3
@normal:
    lda $68
    beq @palette
    jmp $AB7D
@palette:
    jmp StreamPalette
VerticalStream:
    lda $FD
    sta $74
    lda M_PENDING_ATTR
    beq @tiles
    lda #0
    sta M_PENDING_ATTR
    lda $7F13
    cmp #$2B
    beq @skyAttr
    jmp $9537
@skyAttr:
    jmp $97CE
@tiles:
    jsr ForecastStream
    lda M_VRAM_NEXT
    beq @normal
    jsr StreamCell
    sta M_DRAW_CELL
    sty M_DRAW_PAGE
    lda #1
    sta M_PENDING_ATTR
    lda $7F13
    cmp #$2B
    beq @skyTiles
    jmp $951D
@skyTiles:
    jmp $97B4
@normal:
    lda $68
    beq @palette
    lda $7F13
    cmp #$2B
    beq @skyNormal
    jmp $947F
@skyNormal:
    jmp $9716
@palette:
    jmp StreamPalette
.segment "CODE"

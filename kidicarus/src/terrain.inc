; Kid Icarus tile lookups, kept in the Mario PRG bank to avoid two MMC1
; serial bank switches for every collision probe. Address math follows the
; native routines at bank 2:$9394/$AAE1, bank 3:$962B/$B4DD, bank 5:$8B0B.
; The returned $00/$01 pointer is retained for genuine brick mutations.
.export FastTileAt
FastTileAt:
    sta M_PROBE_Y
    sty M_PROBE_X
    sta $02
    sty $03
    lda $7F13
    cmp #$E1
    beq @horizontal
    cmp #$DD
    beq @horizontal
    lda $1A
    and #1
    asl
    tay
    lda $7F13
    cmp #$0B
    beq @fortress
    cmp #$2B
    beq @sky
    lda $7BE0,y
    sta $00
    lda $7BE1,y
    jmp @base
@sky:
    lda $771B,y
    sta $00
    lda $771C,y
    jmp @base
@fortress:
    lda $7011,y
    sta $00
    lda $7012,y
@base:
    sta $01
    lda $FD
    clc
    adc $00
    sta $00
    lda #0
    adc $01
    sta $01
    lda $00
    clc
    adc $02
    and #$F0
    sta $00
    lda $01
    adc #0
    sta $01
    cpy #0
    beq @column
    cmp #7
    bcs @wrap
    lda $00
    cmp #$E0
    bcc @column
@wrap:
    lda $00
    sec
    sbc #$E0
    sta $00
    lda $01
    sbc #1
    sta $01
@column:
    lda $03
    lsr
    lsr
    lsr
    lsr
    ora $00
    sta $00
@read:
    ldy #0
    lda ($00),y
    sta M_TILE
    rts
@horizontal:
    lda $1B
    eor #$FF
    and #1
    asl
    tay
    lda $FE
    clc
    adc $03
    lsr
    lsr
    lsr
    lsr
    clc
    adc @pointers,y
    sta $00
    lda #0
    adc @pointers+1,y
    sta $01
    lda $02
    and #$F0
    clc
    adc $00
    sta $00
    lda #0
    adc $01
    sta $01
    lda $FE
    clc
    adc $03
    bcc @read
    cpy #0
    bne @previousPage
    lda #$F0
    clc
    adc $00
    sta $00
    lda #0
    adc $01
    sta $01
    jmp @read
@previousPage:
    lda $00
    sec
    sbc #$F0
    sta $00
    lda $01
    sbc #0
    sta $01
    jmp @read
@pointers:
    .word $0500,$05F0

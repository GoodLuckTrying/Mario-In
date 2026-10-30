; Native actors keep their original $0200 sprite slots. Mario's eight
; tiles and SMB pickups have separate buffers: the lyre/health pickup owns
; native $50-$5F and must never share them with Mario's lower body.
; Build the next DMA page after native drawing. Mario comes first so enemy
; crowds cannot win the NES eight-sprites-per-scanline priority over him.
ComposeOam:
    lda $A0
    cmp #2
    jcc @nativePage
    cmp #9
    jcs @nativePage
    .repeat 32,I
        lda M_PLAYER_OAM+I
        sta M_DMA_OAM+I
    .endrepeat
    ldx #32
    lda M_ITEM_KIND
    beq @actors
    .repeat 16,I
        lda M_ITEM_OAM+I
        sta M_DMA_OAM+32+I
    .endrepeat
    ldx #48
@actors:
    ; Skip only Pit's former six player sprites. Keep native pickups,
    ; weapons, HUD and enemies, without assigning them new logical slots.
    ; Fixed source offsets avoid a per-sprite index/loop cost in the NMI.
    .repeat 64,I
        .if (I < 8) .or (I >= 14)
            lda $0200+I*4
            cmp #$F0
            bcs :+
            sta M_DMA_OAM,x
            lda $0201+I*4
            sta M_DMA_OAM+1,x
            lda $0202+I*4
            sta M_DMA_OAM+2,x
            lda $0203+I*4
            sta M_DMA_OAM+3,x
            inx
            inx
            inx
            inx
            bne :+
            jmp @full
:
        .endif
    .endrepeat
    stx M_OAM_NEXT_END
    lda M_OAM_END
    beq @clearTail
    cpx M_OAM_END
    bcs @complete
@clearTail:
    lda #$F8
@hideUnused:
    sta M_DMA_OAM,x
    inx
    inx
    inx
    inx
    cpx M_OAM_END
    bne @hideUnused
@complete:
    lda M_OAM_NEXT_END
    sta M_OAM_END
    lda #>M_DMA_OAM
    sta M_DMA_PAGE
    rts
@full:
    stx M_OAM_END
    lda #>M_DMA_OAM
    sta M_DMA_PAGE
    rts
@nativePage:
    lda #2
    sta M_DMA_PAGE
    rts

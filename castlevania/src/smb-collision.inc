; SMB's feet-then-sides contact ordering, reading Castlevania's 8px map.
; Normal motion reaches this routine only after native horizontal/vertical
; dispatch. Stairs, knockback, doors and scripted movement retain native code.
TerrainCollision:
    lda #3
    sta M_COLL_DIR
    lda M_PHYS_STATE
    bne @stateReady
    lda #2
    sta M_PHYS_STATE
@stateReady:
    lda $0142
    and #$FD
    sta $0142
    lda $3F
    cmp #16
    jcc @finish
    sec
    sbc #16
    sta M_COLL_RAW_Y
    cmp #$CF
    jcs @sides
    lda M_VY_HI
    bmi @sides
    lda M_PLATFORM_SLOT
    beq @feet
    lda $0142
    and #4
    bne @land
@feet:
    lda $3F
    clc
    adc #16
    sta M_POINT_Y
    lda $038C
    sec
    sbc #5                    ; SMB left foot: sprite-left +3
    sta M_POINT_X
    jsr TileAtPoint
    bne @footContact
    lda $038C
    clc
    adc #4                    ; SMB right foot: sprite-left +12
    sta M_POINT_X
    jsr TileAtPoint
    beq @sides
@footContact:
    lda M_COLL_RAW_Y
    and #$0F
    cmp #8
    bcc @depth
    ; An isolated 8px platform can begin halfway through an SMB metatile.
    ; Use its own top, while retaining SMB's deep-side response for thick
    ; columns and the authored 16px terrain tested against the original ROM.
    lda M_POINT_Y
    sec
    sbc #8
    sta M_POINT_Y
    jsr TileAtPoint
    bne @thick
    lda M_COLL_RAW_Y
    and #7
    jmp @depth
@thick:
    lda M_COLL_RAW_Y
    and #$0F
@depth:
    cmp #5
    bcc @land
    lda M_MOVING_DIR
    sta M_COLL_SIDE
    jsr SmbImpedeMovement
    jmp @finish
@land:
    lda $3F
    and #$F8
    sta $3F
    lda #0
    sta M_VY_HI
    sta M_VY_LO
    sta M_PHYS_STATE
    lda $0142
    ora #2
    sta $0142
@sides:
    lda #2
    sta M_COLL_SIDE
@side:
    lda $038C
    ldx M_COLL_SIDE
    cpx #2
    bne @right
    sec
    sbc #6                    ; sprite-left +2
    jmp @xReady
@right:
    clc
    adc #5                    ; sprite-left +13
@xReady:
    sta M_POINT_X
    lda M_BODY_TALL
    beq @lower
    lda M_COLL_RAW_Y
    cmp #$20
    bcc @lower
    cmp #$E4
    bcs @lower
    lda $3F
    sec
    sbc #8                    ; raw Y+8
    sta M_POINT_Y
    jsr TileAtPoint
    bne @blocked
@lower:
    lda M_COLL_RAW_Y
    cmp #8
    bcc @next
    cmp #$D0
    bcs @next
    lda $3F
    clc
    adc #8                    ; raw Y+24 (both probes coincide when small)
    sta M_POINT_Y
    jsr TileAtPoint
    bne @blocked
@next:
    dec M_COLL_SIDE
    bne @side
    jmp @finish
@blocked:
    jsr SmbImpedeMovement
@finish:
    lda M_PHYS_STATE
    beq @ground
    lda #1
    bne @action
@ground:
    lda #0
@action:
    sta $046C
    lda $3F
    sta $0354
    ; The screen's left edge clamps position, with SMB's steering exception.
    lda $2E
    ora $2F
    bne @done
    lda $038C
    cmp #8
    bne @done
    lda M_SMB_X_SPEED
    bpl @done
    lda M_INPUT_DIR
    cmp #1
    beq @done
    lda #0
    sta M_SMB_X_SPEED
    sta M_VX_LO
    sta M_VX_HI
@done:
    jmp $C1D4

; Equivalent to SMB ImpedePlayerMove, including its direction mask, one-pixel
; ejection, preserved X fractions and cached absolute speed. X is also moved
; locally so native sprite/camera coordinates continue to agree with world X.
SmbImpedeMovement:
    lda #0
    ldy M_SMB_X_SPEED
    ldx M_COLL_SIDE
    dex
    bne @leftSide
    inx
    cpy #0
    bmi @mask
    lda #$FF
    jmp @stop
@leftSide:
    ldx #2
    cpy #1
    bpl @mask
    lda #1
@stop:
    ldy #0
    sty M_SMB_X_SPEED
    sty M_VX_LO
    sty M_VX_HI
    sta M_COLL_NUDGE
    cmp #0
    bpl @page
    dey
@page:
    sty $00
    clc
    adc $40
    sta $40
    lda $41
    adc $00
    sta $41
    lda $038C
    clc
    adc M_COLL_NUDGE
    sta $038C
@mask:
    txa
    eor #$FF
    and M_COLL_DIR
    sta M_COLL_DIR
    rts

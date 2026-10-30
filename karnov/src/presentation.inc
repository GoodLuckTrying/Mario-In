DrawLives:
 jsr Init
 lda #3
 sta M_POSE
 lda #78
 sta $15
 lda #0
 sta M_PALETTE
 ldx #0
@cell:
 txa
 lsr
 clc
 adc #$21
 sta $0201,x
 lda #0
 sta $0202,x
 lda #143
 cpx #8
 bcc :+
 lda #159
:
 sta $0200,x
 txa
 and #4
 beq :+
 lda #176
 bne @x
:
 lda #168
@x:
 sta $0203,x
 inx
 inx
 inx
 inx
 cpx #16
 bcc @cell
 lda #$F0
 sta $0210
 lda #1
 sta M_ART_READY
 rts
DrawEntrance:
 jsr Init
 lda #$F0
 ldx #$2C
@hide:
 sta $0210,x
 dex
 dex
 dex
 dex
 bpl @hide
 lda #3
 sta M_POSE
 lda #67
 sta $15
 lda #0
 sta M_ATTR
 sta M_PALETTE
 lda #1
 sta M_ART_READY
 jmp DrawBody

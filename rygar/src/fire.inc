; Native Diskarmor and enemy damage remain in charge. Fireballs only add
; independent trajectories and feed the existing enemy weapon-hit flags.
FireUpdate:
 jsr UpdateCamera
 lda $0492
 beq @clear
 lda $28
 and $2A
 and #$40
 beq @move
 ldx #0
 lda FB
 beq @spawn
 ldx #16
 lda FB+16
 bne @move
@spawn:
 lda #1
 sta FB,x
 lda $0512
 clc
 adc #8
 sta FB+1,x
 lda $04F2
 clc
 adc #10
 sta FB+2,x
 lda $04A2
 beq :+
 lda $04F2
 sec
 sbc #10
 sta FB+2,x
:
 lda #3
 sta FB+3,x
 lda #0
 sta FB+4,x
 sta FB+5,x
 lda $04B2
 and #3
 sta FB+6,x
 lda $04A2
 sta FB+7,x
@move:
 ldx #0
 jsr FireOne
 ldx #16
 jmp FireOne
@clear:
 lda #0
 sta FB
 sta FB+16
 rts
FireOne:
 lda FB,x
 jeq @done
 inc FB,x
 stx M_FB
 lda FB+1,x
 sec
 sbc M_CAM_DELTA_X
 sta FB+1,x
 lda FB+2,x
 sec
 sbc M_CAM_DELTA_Y
 sta FB+2,x
 lda FB+7,x
 beq @horizontal
 lda FB+6,x
 cmp #2
 bcc @horizontal
 lda FB+2,x
 ldy FB+6,x
 cpy #3
 beq @up
 clc
 adc #4
 jcs @kill
 jmp @y
@up:
 sec
 sbc #4
 jcc @kill
@y:
 sta FB+2,x
 jmp @probe
@horizontal:
 lda FB+6,x
 and #1
 bne @left
 lda FB+1,x
 clc
 adc #4
 jcs @kill
 jmp @x
@left:
 lda FB+1,x
 sec
 sbc #4
 jcc @kill
@x:
 sta FB+1,x
 lda FB+7,x
 bne @probe
 lda FB+4,x
 clc
 adc FB+5,x
 sta FB+5,x
 lda FB+3,x
 adc FB+2,x
 sta FB+2,x
 lda FB+4,x
 clc
 adc #$50
 sta FB+4,x
 lda FB+3,x
 adc #0
 sta FB+3,x
 bmi @probe
 cmp #4
 bcc @probe
 lda #4
 sta FB+3,x
@probe:
 lda FB+2,x
 cmp #8
 jcc @kill
 cmp #216
 jcs @kill
 jsr FireProbe
 ldx M_FB
 lda M_PROBE_COLLISION
 and #$0C
 bne @kill
 lda M_PROBE_COLLISION
 and #3
 beq @enemy
 lda FB+7,x
 bne @kill
 lda FB+3,x
 bmi @kill
 lda #$FD
 sta FB+3,x
 lda #0
 sta FB+4,x
@enemy:
 jsr FireEnemy
@done:rts
@kill:
 lda #0
 sta FB,x
 rts
FireProbe:
 lda $1E
 sta M_OLD_ACTOR
 ldx #0
 ldy #0
@save:
 lda $04A1,y
 sta M_PROBE_SAVE,x
 tya
 clc
 adc #16
 tay
 inx
 cpx #10
 bcc @save
 lda #$80
 sta $04A1
 lda #2
 sta $04B1
 lda #0
 sta $04F1
 sta $0511
 sta $04
 sta $06
 ldx M_FB
 lda FB+2,x
 sec
 sbc #4
 sta $0501
 sta $05
 lda FB+1,x
 sec
 sbc #6
 sta $0521
 sta $07
 lda FB+3,x
 asl
 asl
 asl
 asl
 asl
 sta $04D1
 lda #$40
 ldy FB+6,x
 tya
 and #1
 beq :+
 lda #$C0
 bne @vx
:
 lda #$40
@vx:
 sta $04E1
 lda #15
 sta $1E
 tax
 jsr $9273
 lda #0
 sta $00
 lda $0531
 ldy #3
@bits:
 asl
 rol $00
 asl
 dey
 bpl @bits
 lda $00
 and #15
 jsr $90CF
 lda $09
 sta M_PROBE_COLLISION
 ldx #0
 ldy #0
@restore:
 lda M_PROBE_SAVE,x
 sta $04A1,y
 tya
 clc
 adc #16
 tay
 inx
 cpx #10
 bcc @restore
 lda M_OLD_ACTOR
 sta $1E
 rts
FireEnemy:
 lda $04F3
 sta M_OLD_Y
 lda $0513
 sta M_OLD_X
 ldy #13
@save:
 lda $05BE,y
 sta M_HIT_SAVE,y
 dey
 bpl @save
 ldx M_FB
 lda FB+1,x
 sta $0513
 lda FB+2,x
 sta $04F3
 jsr $ACF5
 lda M_OLD_Y
 sta $04F3
 lda M_OLD_X
 sta $0513
 ldy #13
@check:
 lda $05BE,y
 eor M_HIT_SAVE,y
 and #$20
 bne @hit
 dey
 bpl @check
 rts
@hit:
 ldx M_FB
 lda #0
 sta FB,x
 rts
FireDraw:
 ldx #0
 ldy #0
 jsr FireCell
 ldx #16
 ldy #4
FireCell:
 lda FB,x
 beq @done
 lda FB+1,x
 sta $0203,y
 lda FB+2,x
 sta $0200,y
 lda $32
 and #4
 lsr
 lsr
 tax
 lda FireTiles,x
 sta $0201,y
 lda #0
 sta $0202,y
@done:rts

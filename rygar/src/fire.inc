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
 cmp #8
 jcc @kill
 cmp #216
 jcs @kill
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
 jmp @overheadY
@up:
 sec
 sbc #4
 jcc @kill
@overheadY:
 sta FB+2,x
 jmp @overhead
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
 jne @overhead
 ; Only solid tiles at the leading side can stop horizontal travel.
 ; A floor under the feet must never become a side-wall collision.
 lda FB+1,x
 ldy FB+6,x
 cpy #1
 beq :+
 clc
 adc #7
:
 tax
 ldy M_FB
 lda FB+2,y
 clc
 adc #4
 tay
 jsr FirePoint
 and #2
 jne @killReload
 ldx M_FB
 lda FB+4,x
 clc
 adc FB+5,x
 sta FB+5,x
 lda FB+3,x
 adc #0
 sta M_DIR
 bpl :+
 eor #$FF
 clc
 adc #1
:
 sta M_STEPS
 lda FB+4,x
 clc
 adc #$50
 sta FB+4,x
 lda FB+3,x
 adc #0
 sta FB+3,x
 bmi @vertical
 cmp #4
 bcc @vertical
 lda #4
 sta FB+3,x
@vertical:
 lda M_STEPS
 jeq @enemy
@pixel:
 lda M_DIR
 bmi @rising
 inc FB+2,x
 lda FB+2,x
 clc
 adc #8
 bcs @kill
 tay
 jsr FireFeet
 ldx M_FB
 cmp #0
 beq @next
 ; Align the visible eight-pixel ball above the first solid floor pixel.
 dec FB+2,x
 lda #$FD
 sta FB+3,x
 lda #0
 sta FB+4,x
 sta FB+5,x
 jmp @enemy
@rising:
 dec FB+2,x
 lda FB+2,x
 clc
 adc #1
 tay
 jsr FireFeet
 ldx M_FB
 and #2
 bne @kill
@next:
 lda FB+2,x
 cmp #8
 bcc @kill
 cmp #216
 bcs @kill
 dec M_STEPS
 bne @pixel
 jmp @enemy
@overhead:
 lda FB+1,x
 clc
 adc #4
 tay
 lda FB+2,x
 clc
 adc #4
 sta M_POINT_Y
 tya
 tax
 ldy M_POINT_Y
 jsr FirePoint
 ldx M_FB
 cmp #0
 bne @kill
 lda FB+2,x
 cmp #8
 bcc @kill
 cmp #216
 bcs @kill
@enemy:
 jsr FireEnemy
@done:rts
@killReload:
 ldx M_FB
@kill:
 lda #0
 sta FB,x
 rts
FireFeet:
 ; Probe both feet (or both top corners on ascent), never a host actor box.
 sty M_POINT_Y
 lda FB+1,x
 clc
 adc #2
 tax
 jsr FirePoint
 sta M_POINT_BITS
 ldx M_FB
 lda FB+1,x
 clc
 adc #5
 tax
 ldy M_POINT_Y
 jsr FirePoint
 ora M_POINT_BITS
 rts
FirePoint:
 ; Native collision bitmap: 33 wrapping columns, four bytes per column.
 ; Plane one contains one-way floors; plane two contains solid terrain.
 ; Keep the native 240-line Y wrap and fractional camera page bits.
 tya
 clc
 adc $16
 bcc :+
 adc #$0F
:
 cmp #$F0
 bcc :+
 and #$0F
:
 sta M_POINT_WORLD_Y
 lda $15
 and #$0F
 sta $01
 txa
 clc
 adc $17
 bcc :+
 inc $01
:
 lsr $01
 ror
 lsr $01
 ror
 lsr $01
 ror
 sta $00
 lda #0
 sta $01
 lda #33
 jsr $C55D
 asl
 asl
 sta M_POINT_COLUMN
 lda M_POINT_WORLD_Y
 lsr
 lsr
 lsr
 pha
 and #7
 tax
 lda $C555,x
 sta M_POINT_MASK
 pla
 lsr
 lsr
 lsr
 ora M_POINT_COLUMN
 tay
 lda #0
 sta M_POINT_RESULT
 lda $038A,y
 and M_POINT_MASK
 beq :+
 inc M_POINT_RESULT
:
 lda $040E,y
 and M_POINT_MASK
 beq :+
 lda #2
 ora M_POINT_RESULT
 sta M_POINT_RESULT
:
 lda M_POINT_RESULT
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

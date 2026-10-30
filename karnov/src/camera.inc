CanScrollDown:
 ; A horizontal strip must finish before the host can choose a vertical one.
 ; Use the same level bounds and two map columns as native $B19F/$B124,
 ; including its down-scroll lock, rather than treating that wait as a pit.
 lda $C4
 and #$B0
 cmp #$90
 beq @yes
 lda $5D
 and #$20
 bne @no
 lda $A0
 cmp #$24
 bcs @no
 clc
 adc #12
 tay
 ldx $9F
 jsr $C36B
 bmi @no
 lda $A0
 clc
 adc #12
 tay
 lda $9F
 clc
 adc #15
 tax
 jsr $C36B
 bmi @no
@yes:
 sec
 rts
@no:
 clc
 rts
CameraStep:
 jsr $B643
 lda M_ACTIVE
 jeq @done
 lda $C4
 jpl @done
 and #$20
 jne @done
 lda $C5
 cmp #15
 jcs @done
 ; Keep both terrain upload packets. Repeating the native scroll without
 ; this queue would overwrite the first row's tiles and attributes.
 ldx #13
@save:
 lda $CA,x
 sta M_SCROLL_PACKET,x
 dex
 bpl @save
 jsr $B8A3
 lda #0
 sta M_SCROLL_PACKET+14
 lda $C4
 and #8
 beq @advance
 lda $C5
 cmp #13
 bcs @attributes
 sec
 sbc #1
 asl
 asl
 asl
 asl
 tax
 clc
 adc $0562
 sta M_SCROLL_PACKET+15
 lda #0
 adc $0563
 sta M_SCROLL_PACKET+16
 ldy #0
@hud:
 lda $0564,x
 sta M_SCROLL_PACKET+17,y
 inx
 iny
 cpy #16
 bcc @hud
 lda #16
 bne @count
@attributes:
 sec
 sbc #13
 asl
 asl
 clc
 adc $A3
 sta M_SCROLL_PACKET+15
 lda #0
 adc $A4
 sta M_SCROLL_PACKET+16
 lda $A5
 ldx #3
@attr:
 sta M_SCROLL_PACKET+17,x
 dex
 bpl @attr
 lda #4
@count:
 sta M_SCROLL_PACKET+14
@advance:
 jsr $AF3F
 jsr $B643
 lda #1
 sta M_QUEUE_READY
@done:rts
ScrollUpload:
 lda M_QUEUE_READY
 beq @native
 ldy M_SCROLL_PACKET
 ldx M_SCROLL_PACKET+1
 jsr $C152
 lda M_SCROLL_PACKET+2
 sta $2007
 lda M_SCROLL_PACKET+3
 sta $2007
 ldy M_SCROLL_PACKET+4
 ldx M_SCROLL_PACKET+5
 jsr $C152
 lda M_SCROLL_PACKET+6
 sta $2007
 lda M_SCROLL_PACKET+7
 sta $2007
 ldy M_SCROLL_PACKET+8
 ldx M_SCROLL_PACKET+9
 jsr $C152
 lda M_SCROLL_PACKET+10
 sta $2007
 ldy M_SCROLL_PACKET+11
 ldx M_SCROLL_PACKET+12
 jsr $C152
 lda M_SCROLL_PACKET+13
 sta $2007
 lda M_SCROLL_PACKET+14
 beq @done
 ldy M_SCROLL_PACKET+15
 ldx M_SCROLL_PACKET+16
 jsr $C152
 ldx #0
@hud:
 lda M_SCROLL_PACKET+17,x
 sta $2007
 inx
 cpx M_SCROLL_PACKET+14
 bcc @hud
@done:
 lda #0
 sta M_QUEUE_READY
@native:
 jmp $E0F7

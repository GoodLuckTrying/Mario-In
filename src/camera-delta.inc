; Integer camera displacement, kept separate from a host's velocity units.
; HOST_SCROLL_Y wraps at 240 for native vertical nametable scrolling.
UpdateCamera:
 lda HOST_SCROLL_X
 sec
 sbc M_LAST_SCROLL_X
 sta M_CAM_DELTA_X
 lda HOST_SCROLL_X
 sta M_LAST_SCROLL_X
 lda HOST_SCROLL_Y
 sec
 sbc M_LAST_SCROLL_Y
 sta M_CAM_DELTA_Y
 lda HOST_SCROLL_Y
 cmp #$40
 bcs @negative
 lda M_LAST_SCROLL_Y
 cmp #$C0
 bcc @done
 cmp #$F0
 bcs @done
 lda M_CAM_DELTA_Y
 sec
 sbc #16
 sta M_CAM_DELTA_Y
 jmp @done
@negative:
 cmp #$C0
 bcc @done
 cmp #$F0
 bcs @done
 lda M_LAST_SCROLL_Y
 cmp #$40
 bcs @done
 lda M_CAM_DELTA_Y
 clc
 adc #16
 sta M_CAM_DELTA_Y
@done:
 lda HOST_SCROLL_Y
 sta M_LAST_SCROLL_Y
 rts

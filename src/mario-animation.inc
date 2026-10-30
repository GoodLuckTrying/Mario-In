; Three SMB walk frames, clocked by the source animation interval rather
; than a host counter that may also be reset by enemy spawning or music.
AnimateMario:
 lda M_STATE
 bne @done
 lda M_SMB_X_ABS
 beq @idle
 lda M_ANIM_SET
 jmp AnimateInterval
@idle:
 lda #0
 sta M_ANIM
 sta M_TIMER
@done:rts
AnimateInterval:
 sta M_TMP
 lda M_TIMER
 beq @advance
 dec M_TIMER
 rts
@advance:
 lda M_TMP
 sta M_TIMER
 inc M_ANIM
 lda M_ANIM
 cmp #3
 bcc @done
 lda #0
 sta M_ANIM
@done:rts
AnimateClimb:
 lda M_TIMER
 beq @advance
 dec M_TIMER
 rts
@advance:
 lda #6
 sta M_TIMER
 lda M_ANIM
 eor #1
 and #1
 sta M_ANIM
 rts

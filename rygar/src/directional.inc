DirectionalPose:
 lda M_OAMY
 sec
 sbc #24
 sta M_OAMY
 lda $28
 and #$0F
 beq @idle
 pha
 lda #0
 sta M_VIEW_FLIP
 pla
 and #2
 beq :+
 lda #$40
 sta M_VIEW_FLIP
:
 lda #2
 sta M_VIEW
 lda $28
 and #8
 beq @front
 lda #4
 sta M_VIEW
 lda $28
 and #3
 beq @walk
 dec M_VIEW
 jmp @walk
@front:
 lda $28
 and #4
 beq @walk
 lda #0
 sta M_VIEW
 lda $28
 and #3
 beq @walk
 inc M_VIEW
@walk:
 lda M_ANIM
 clc
 adc #1
 bne @frame
@idle:
 lda #0
@frame:
 sta M_TMP
 lda M_VIEW
 asl
 asl
 clc
 adc M_TMP
 sta M_DYN_WANT
 rts
StreamArt:
 lda M_MAGIC
 cmp #$4D
 jne @done
 lda M_DYNAMIC
 jeq @done
 lda M_VRAM_PENDING
 cmp #8
 jcs @done
 lda M_DYN_PHASE
 bne @copy
 lda M_DYN_WANT
 cmp M_DYN_SHOWN
 jeq @done
 sta M_DYN_TARGET
 lda M_DYN_BUFFER
 eor #8
 sta M_DYN_WRITE
@copy:
 lda M_DYN_TARGET
 lsr
 clc
 adc #>DynamicFrames
 sta $01
 lda M_DYN_TARGET
 and #1
 lsr
 ror
 sta $00
 lda M_DYN_PHASE
 asl
 asl
 asl
 asl
 asl
 ora $00
 sta $00
 lda $2002
 lda M_DYN_WRITE
 lsr
 lsr
 lsr
 lsr
 sta $2006
 lda M_DYN_WRITE
 asl
 asl
 asl
 asl
 sta M_TMP
 lda M_DYN_PHASE
 asl
 asl
 asl
 asl
 asl
 ora M_TMP
 sta $2006
 ldy #0
 .repeat 32
  lda ($00),y
  sta $2007
  iny
 .endrepeat
 inc M_DYN_PHASE
 lda M_DYN_PHASE
 cmp #4
 bcc @done
 lda #0
 sta M_DYN_PHASE
 lda M_DYN_TARGET
 sta M_DYN_SHOWN
 lda M_DYN_WRITE
 sta M_DYN_BUFFER
 lda #1
 sta M_DYN_READY
@done:rts

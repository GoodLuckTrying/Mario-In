.export ActiveBody, SideResolve, SavePiece, PieceSides
; The live piece is separate from the settled terrain. Test its actual
; four cells, preserving holes and the grid-probe scratch used by MoveX.
ActiveBody:
 lda N_playState
 cmp #1
 beq :+
 cmp #2
 jne @empty
:
 lda N_currentPiece
 cmp #19
 jcs @empty
 asl
 asl
 sta S_INDEX
 asl
 clc
 adc S_INDEX
 sta S_INDEX
 lda #4
 sta S_N
@cell:
 ldx S_INDEX
 lda N_orientationTable+2,x
 clc
 adc N_tetriminoX
 cmp #10
 bcs @next
 asl
 asl
 asl
 clc
 adc #96
 sta S_BX
 lda M_X
 clc
 adc #13
 cmp S_BX
 bcc @next
 lda S_BX
 clc
 adc #8
 sta S_EDGE
 lda M_X
 clc
 adc #2
 cmp S_EDGE
 bcs @next
 lda N_orientationTable,x
 clc
 adc N_tetriminoY
 cmp #20
 bcs @next
 asl
 asl
 asl
 clc
 adc #48
 sta S_BY
 lda M_Y
 cmp S_BY
 bcc @next
 beq @next
 lda S_BY
 clc
 adc #8
 sta S_EDGE
 lda M_Y
 sec
 sbc #15
 cmp S_EDGE
 bcs @next
 lda #1
 rts
@next:
 lda S_INDEX
 clc
 adc #3
 sta S_INDEX
 dec S_N
 bne @cell
@empty:
 lda #0
 rts

SavePiece:
 lda N_tetriminoX
 sta S_OLD_X
 lda N_tetriminoY
 sta S_OLD_Y
 lda N_currentPiece
 sta S_OLD_POSE
 lda #1
 sta S_CAN_REJECT
 rts
PieceSides:
 lda #1
 sta S_HORIZONTAL
 jsr Contacts
 lda #0
 sta S_HORIZONTAL
 lda M_DEAD
 ora M_STOMP
 rts

SideResolve:
 jsr ActiveBody
 jeq @done
 lda M_X
 sta S_START_X
 lda #0
 sta S_TRIED
 lda #1
 sta S_DIR
 lda S_HORIZONTAL
 beq @nearest
 lda N_tetriminoX
 cmp S_OLD_X
 beq @nearest
 bcc @left
 lda S_HORIZONTAL
 bne @try
@nearest:
 lda N_tetriminoX
 asl
 asl
 asl
 clc
 adc #96
 sta S_EDGE
 lda M_X
 clc
 adc #8
 cmp S_EDGE
 bcs @try
@left:
 lda #$FF
 sta S_DIR
@try:
 lda #8
 sta S_STEPS
@push:
 ; Move to this cell's edge, then test again for the remaining minos.
 ; Checking the swept path in eight-pixel steps covers every solid tile
 ; without repeating nine terrain probes for every single push pixel.
 lda S_DIR
 bmi @targetLeft
 lda S_BX
 clc
 adc #6
 bne @target
@targetLeft:
 lda S_BX
 sec
 sbc #14
@target:
 cmp #96
 bcc @blocked
 cmp #161
 bcs @blocked
 sta S_TARGET
@path:
 lda S_DIR
 bmi @pathLeft
 lda S_TARGET
 sec
 sbc M_X
 cmp #8
 bcc @endPath
 lda M_X
 clc
 adc #8
 bne @pathProbe
@pathLeft:
 lda M_X
 sec
 sbc S_TARGET
 cmp #8
 bcc @endPath
 lda M_X
 sec
 sbc #8
 bne @pathProbe
@endPath:
 lda S_TARGET
@pathProbe:
 sta M_X
 jsr Body
 bne @blocked
 lda M_X
 cmp S_TARGET
 bne @path
 jsr ActiveBody
 beq @moved
 dec S_STEPS
 bne @push
@blocked:
 lda S_START_X
 sta M_X
 lda S_HORIZONTAL
 beq :+
 lda N_tetriminoX
 cmp S_OLD_X
 bne @reject
:
 lda S_TRIED
 bne @reject
 inc S_TRIED
 lda S_DIR
 eor #$FE
 sta S_DIR
 jsr ActiveBody
 jmp @try
@reject:
 lda S_CAN_REJECT
 beq @done
 lda S_OLD_X
 sta N_tetriminoX
 lda S_OLD_Y
 sta N_tetriminoY
 lda S_OLD_POSE
 sta N_currentPiece
 lda #1
 sta N_playState
 rts
@moved:
 lda #0
 sta M_SMB_X_SPEED
 sta M_SMB_X_FORCE
 sta M_XF
@done:
 rts

.export AHunt,AHuntBounds
; Below level ten the committed piece plays its Tetris plan. Above it,
; steer during descent, with increasingly short decision intervals.
AHunt:
 lda N_levelNumber
 cmp #10
 jcc @done
 lda A_DODGE
 beq :+
 dec A_DODGE
:
 lda A_RETRY
 sta A_TRIED
 jne @retry
 jsr AHuntBounds
 lda M_VY
 bmi @track
 lda M_Y
 cmp A_MIN_Y
 bcs @track
 lda A_MIN_Y
 sec
 sbc M_Y
 cmp #33
 bcs @track
 lda M_X
 clc
 adc #13
 cmp A_MIN_X
 bcc @track
 lda A_MAX_X
 clc
 adc #8
 sta S_EDGE
 lda M_X
 clc
 adc #2
 cmp S_EDGE
 bcs @track
 lda A_EVADE
 beq :+
 dec A_EVADE
 lda A_EVADE_DIR
 sta A_DIR
 jmp @attempt
:
 lda A_DODGE
 bne @track
 jsr AHuntRate
 sta A_DODGE
 jsr AHuntDirection
 bne :+
 lda #2
:
 eor #3
 sta A_DIR
 sta A_EVADE_DIR
 lda #2
 sta A_EVADE
 jmp @attempt
@track:
 lda #0
 sta A_EVADE
 lda A_TRACK
 beq :+
 dec A_TRACK
 rts
:
 jsr AHuntDirection
 sta A_DIR
 jeq @done
 jmp @attempt
@retry:
 sta A_DIR
 lda #0
 sta A_RETRY
@attempt:
 jsr AHuntRate
 sta A_TRACK
 lda N_tetriminoX
 sta A_SAVE_X
 lda A_DIR
 cmp #1
 bne :+
 inc N_tetriminoX
 bne @valid
:
 dec N_tetriminoX
@valid:
 jsr N_isPositionValid
 bne @unsafe
 lda V_REV
 cmp A_HEIGHT_REV
 beq :+
 jsr AHeights
:
 lda A_BEST_HI
 sta A_OLD_BEST
 lda #$FF
 sta A_BEST_HI
 lda N_currentPiece
 sta A_ROT
 lda N_tetriminoX
 sta A_X
 jsr ACandidate
 lda A_BEST_HI
 cmp #$FF
 beq @restoreUnsafe
 lda A_Y
 cmp N_tetriminoY
 bcc @restoreUnsafe
 lda A_OLD_BEST
 sta A_BEST_HI
 lda A_SAVE_X
 sta N_tetriminoX
 lda A_DIR
 sta N_heldButtons
 sta N_newlyPressedButtons
 lda #3
 sta A_STATE
 rts
@restoreUnsafe:
 lda A_OLD_BEST
 sta A_BEST_HI
@unsafe:
 lda #3
 sta A_STATE
 lda A_SAVE_X
 sta N_tetriminoX
 lda A_TRIED
 bne @done
 lda A_DIR
 eor #3
 sta A_RETRY
@done:
 rts
AHuntDirection:
 lda M_X
 clc
 adc #8
 sec
 sbc #96
 lsr
 lsr
 lsr
 cmp N_tetriminoX
 beq @same
 lda #1
 bcs :+
 lda #2
:
 rts
@same:
 lda #0
 rts
AHuntRate:
 lda N_levelNumber
 cmp #34
 bcs @fast
 sta A_TEMP
 lda #40
 sec
 sbc A_TEMP
 rts
@fast:
 lda #6
 rts
AHuntBounds:
 lda #$FF
 sta A_MIN_X
 sta A_MIN_Y
 lda #0
 sta A_MAX_X
 lda N_currentPiece
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
 asl
 asl
 asl
 clc
 adc #96
 cmp A_MIN_X
 bcs :+
 sta A_MIN_X
:
 cmp A_MAX_X
 bcc :+
 sta A_MAX_X
:
 lda N_orientationTable,x
 clc
 adc N_tetriminoY
 asl
 asl
 asl
 clc
 adc #48
 cmp A_MIN_Y
 bcs :+
 sta A_MIN_Y
:
 lda S_INDEX
 clc
 adc #3
 sta S_INDEX
 dec S_N
 bne @cell
 rts

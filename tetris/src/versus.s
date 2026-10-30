; One native Tetris board. Controller ownership changes only in VS;
; the original single-player piece engine and menus remain available.
.export MenuGate, VInputs, VAdvance, VStats, VFair, VControls, VLock, AI, APlan, AHeights, ACandidate
.segment "BOOT"
MenuGate:
 lda #0
 sta V_MODE
 sta V_PAGE
 sta V_SELECT
 sta V_ESCAPES
@screen:
 lda #0
 sta N_renderMode
 jsr N_updateAudioWaitForNmiAndDisablePpuRendering
 jsr N_disableNmi
 lda #0
 jsr N_changeCHRBank0
 lda #0
 jsr N_changeCHRBank1
 jsr N_bulkCopyToPpu
 .addr N_menu_palette
 ; The normal menu font is 0..9, A..Z = $0A..$23, blank = $FF.
 bit $2002
 lda #$20
 sta $2006
 lda #0
 sta $2006
 ldy #4
 ldx #0
 lda #$FF
@blank:
 sta $2007
 inx
 bne @blank
 dey
 bne @blank
 ; Give all text the first background palette.
 bit $2002
 lda #$23
 sta $2006
 lda #$C0
 sta $2006
 ldx #64
 lda #0
@attr:
 sta $2007
 dex
 bne @attr
 jsr N_bulkCopyToPpu
 .addr MenuText
 lda V_PAGE
 beq @main
 jsr N_bulkCopyToPpu
 .addr VsText
 jmp @ready
@main:
 jsr N_bulkCopyToPpu
 .addr MainText
@ready:
 jsr N_waitForVBlankAndEnableNmi
 jsr N_updateAudioWaitForNmiAndResetOamStaging
 jsr N_updateAudioWaitForNmiAndEnablePpuRendering
@wait:
 ; Native paired brackets mark the selected row.
 lda #84
 sta N_spriteXOffset
 lda V_SELECT
 asl
 asl
 asl
 asl
 asl
 clc
 adc #111
 sta N_spriteYOffset
 lda #1
 sta N_spriteIndexInOamContentLookup
 jsr N_loadSpriteIntoOamStaging
 ldx N_oamStagingLength
 lda #180
 sta $01FF,x
 jsr N_updateAudioWaitForNmiAndResetOamStaging
 ; Hidden shortcut belongs only to the first Solo/VS page. Check it
 ; before Select can move the cursor, including simultaneous presses.
 lda V_PAGE
 bne @navigate
 lda N_heldButtons_player1
 and #$20
 beq @navigate
 lda N_newlyPressedButtons_player1
 and #$10
 beq @navigate
 lda #3
 sta V_MODE
 lda #2
 sta N_soundEffectSlot1Init
 jmp @level
@navigate:
 lda N_newlyPressedButtons_player1
 and #$2F
 beq @confirm
 lda V_SELECT
 eor #1
 sta V_SELECT
 lda #1
 sta N_soundEffectSlot1Init
@confirm:
 lda N_newlyPressedButtons_player1
 and #$40
 bne @back
 lda N_newlyPressedButtons_player1
 and #$90
 beq @wait
 lda #2
 sta N_soundEffectSlot1Init
 lda V_PAGE
 bne @vs
 lda V_SELECT
 beq @solo
 lda #1
 sta V_PAGE
 lda #0
 sta V_SELECT
 jmp @screen
@solo:
 lda #2
 sta V_PAGE
 jmp N_gameMode_gameTypeMenu
@vs:
 lda V_SELECT
 clc
 adc #1
 sta V_MODE
@level:
 lda #0
 sta N_gameType
 lda #1
 sta N_numberOfPlayers
 lda #3
 sta N_gameMode
 rts
@back:
 lda V_PAGE
 beq @title
 lda #0
 sta V_PAGE
 sta V_SELECT
 jmp @screen
@title:
 lda #1
 sta N_gameMode
 rts

; Packed PPU strings use the native bulk-copy format.
.repeat 26,I
 .charmap $41+I, $0A+I
.endrepeat
.charmap $20, $FF
.charmap $31, $01
.charmap $32, $02
MenuText:
 .byte $21,$0A,.strlen("MARIO TETRIS"),"MARIO TETRIS"
 .byte $22,$A4,.strlen("D PAD MOVE  A START  B BACK"),"D PAD MOVE  A START  B BACK"
 .byte $FF
MainText:
 .byte $21,$CD,.strlen("SOLO"),"SOLO"
 .byte $22,$4D,.strlen("VS"),"VS"
 .byte $FF
VsText:
 .byte $21,$CD,.strlen("VS CPU"),"VS CPU"
 .byte $22,$4D,.strlen("VS HUMAN"),"VS HUMAN"
 .byte $22,$E4,.strlen("P1 MARIO   P2 TETRIS"),"P1 MARIO   P2 TETRIS"
 .byte $FF
VsLabels:
 .byte "VS CPU ","VS P2  ","AUTO   "

VHud:
 lda V_HUD
 beq @done
 lda V_MODE
 beq @done
 lda N_gameMode
 cmp #4
 bne @done
 lda N_renderMode
 cmp #3
 bne @done
 lda N_player1_vramRow
 cmp #20
 bcc @done
 lda N_outOfDateRenderFlags
 bne @done
 lda #0
 sta V_HUD
 bit $2002
 lda #$20
 sta $2006
 lda #$82
 sta $2006
 ldx #0
 lda V_MODE
 cmp #2
 bne :+
 ldx #7
:
 cmp #3
 bne :+
 ldx #14
:
 ; A-TYPE occupies seven tiles including the final E.
 ldy #7
@text:
 lda VsLabels,x
 sta $2007
 inx
 dey
 bne @text
@done:
 rts

.segment "CODE"
VInputs:
 lda V_MODE
 beq @done
 lda V_WARNING
 beq :+
 dec V_WARNING
:
 lda V_MODE
 cmp #1
 jeq AI
 cmp #3
 jeq AI
 lda N_heldButtons_player2
 and #$CF
 sta N_heldButtons
 lda N_newlyPressedButtons_player2
 and #$CF
 sta N_newlyPressedButtons
@done:
 rts

; Capture the native line counter before scoring, then make each additional
; ten lines a permanent level even after earlier Mario escapes.
VStats:
 lda V_MODE
 cmp #3
 jeq N_playState_updateLinesAndStatistics
 lda N_levelNumber
 sta V_LEVEL_BEFORE
 lda N_lines
 and #$F0
 sta V_LINES_BEFORE
 jsr N_playState_updateLinesAndStatistics
 lda V_MODE
 beq @done
 lda N_lines
 and #$F0
 cmp V_LINES_BEFORE
 beq @done
 lda N_levelNumber
 cmp V_LEVEL_BEFORE
 bne @done
 inc N_levelNumber
 lda N_levelNumber
 cmp #100
 bcc :+
 lda #99
 sta N_levelNumber
:
 lda #6
 sta N_soundEffectSlot1Init
 lda N_outOfDateRenderFlags
 ora #2
 sta N_outOfDateRenderFlags
@done:
 lda V_MODE
 beq @return
 lda N_levelNumber
 cmp #100
 bcc @return
 lda #99
 sta N_levelNumber
@return:
 rts

VAdvance:
 lda N_levelNumber
 sta V_CLEARED_LEVEL
 sec
 sbc V_ROUND_START
 sta V_CLEAR_GAIN
 lda #0
 sta V_PENDING
 sta A_STATE
 lda N_levelNumber
 cmp #99
 bcs :+
 inc N_levelNumber
:
 lda N_levelNumber
 sta V_ROUND_START
 inc V_ESCAPES
 ; Keep current level, cumulative lines, score and piece statistics.
 ; Only the board and active-piece phase reset between VS rounds.
 lda #$EF
 ldx #0
@board:
 sta $0400,x
 inx
 cpx #200
 bne @board
 lda #0
 sta N_vramRow
 sta N_player1_vramRow
 sta N_completedLines
 sta N_lineIndex
 sta N_holdDownPoints
 sta N_fallTimer
 sta N_autorepeatX
 sta N_autorepeatY
 sta V_CLOCK
 lda #19
 sta N_currentPiece
 lda #8
 sta N_playState
 lda #$47
 sta N_outOfDateRenderFlags
 jsr Init
 lda #45
 sta V_WARNING
 lda #6
 sta N_soundEffectSlot1Init
 lda #180
 sta V_CLEAR
 rts

; The safety window is attached to a piece rather than frame-counter
; parity. VS input cannot accelerate it away. Mario still moves throughout.
VFair:
 lda V_MODE
 beq @done
 lda N_levelNumber
 cmp #100
 bcc :+
 lda #99
 sta N_levelNumber
:
 lda N_playState
 cmp #8
 bne :+
 lda #0
 sta A_STATE
 sta V_CLOCK
 lda #45
 sta V_WARNING
:
@done:
 rts

VControls:
 lda V_MODE
 cmp #3
 bne :+
 jsr N_shift_tetrimino
 jsr N_rotate_tetrimino
 lda A_STATE
 cmp #3
 bne @done
 jmp N_drop_tetrimino
:
 jsr SavePiece
 jsr N_shift_tetrimino
 jsr PieceSides
 jne @done
 jsr SavePiece
 jsr N_rotate_tetrimino
 jsr PieceSides
 jne @done
 lda V_MODE
 beq @drop
 lda V_WARNING
 bne @done
 lda V_MODE
 cmp #1
 bne @clock
 lda A_STATE
 cmp #3
 bne @done
@clock:
 inc V_CLOCK
 ; Native gravity, with a six-frame floor for reaction time. Soft drop
 ; uses the same floor, so neither the CPU nor P2 can bypass it.
 lda #6
 sta A_TEMP
 lda N_heldButtons
 and #4
 bne @speed
 ldx N_levelNumber
 cpx #29
 bcs @speed
 lda N_framesPerDropTable,x
 cmp #6
 bcc @speed
 sta A_TEMP
@speed:
 lda V_CLOCK
 cmp A_TEMP
 bcc @done
 lda #0
 sta V_CLOCK
 sta N_autorepeatY
 lda #48
 sta N_fallTimer
@drop:
 jsr SavePiece
 jmp N_drop_tetrimino
@done:
 rts

VLock:
 lda V_MODE
 beq @native
 cmp #3
 beq @native
 jsr N_isPositionValid
 bne @yield
 ; Mario may have broken a supporting cell during the lock interval.
 ; Resume falling instead of solidifying a floating piece.
 inc N_tetriminoY
 jsr N_isPositionValid
 dec N_tetriminoY
 cmp #0
 bne @support
 lda #1
 sta N_playState
 rts
@support:
 lda V_MODE
 cmp #1
 bne @native
 lda V_REV
 cmp A_REV
 beq @native
 ; A committed piece keeps falling naturally if Mario changes terrain.
 ; Recheck its final placement here instead of teleporting it to spawn.
 jsr AHeights
 lda N_currentPiece
 sta A_ROT
 lda N_tetriminoX
 sta A_X
 lda #$FF
 sta A_BEST_HI
 jsr ACandidate
 lda A_BEST_HI
 cmp #$FF
 bne @native
@yield:
 ; Blocked spawns yield a piece, never an automatic Tetris loss for Mario.
 lda #19
 sta N_currentPiece
 lda #8
 sta N_playState
 rts
@native:
 jmp N_playState_lockTetrimino

AI:
 lda #0
 sta N_heldButtons
 sta N_newlyPressedButtons
 lda N_playState
 cmp #1
 beq :+
 lda #0
 sta A_STATE
 rts
:
 lda A_STATE
 bne @state
 jsr APlan
 rts
@state:
 lda A_STATE
 cmp #3
 beq @committed
 lda V_REV
 cmp A_REV
 beq :+
 jsr APlan
 rts
:
@committed:
 lda A_STATE
 cmp #1
 bne @steer
 jsr ACandidate
 ; One candidate per update leaves the NMI and Mario physics time.
 lda #0
 sta N_fallTimer
 rts
@steer:
 lda A_BEST_HI
 cmp #$FF
 bne @have
 lda V_MODE
 cmp #3
 jeq @fallback
 ; No safe placement: yield this piece instead of topping Mario out.
 lda #19
 sta N_currentPiece
 lda #8
 sta N_playState
 rts
@have:
 lda A_STATE
 cmp #3
 beq @drop
 lda #0
 sta N_fallTimer
 inc A_TICK
 lda A_TICK
 cmp #96
 bcc :+
 lda V_MODE
 cmp #3
 jeq @fallback
 lda #$FF
 sta A_BEST_HI
 rts
:
 lda A_TICK
 and #3
 bne @done
 lda N_currentPiece
 cmp A_BEST_ROT
 beq @horizontal
 lda #$80
 sta N_newlyPressedButtons
 sta N_heldButtons
 rts
@horizontal:
 lda N_tetriminoX
 cmp A_BEST_X
 beq @commit
 lda #1
 bcc :+
 lda #2
:
 sta N_newlyPressedButtons
 sta N_heldButtons
 rts
@commit:
 lda #3
 sta A_STATE
 lda #30
 sta V_WARNING
 lda #0
 sta A_TRACK
 sta A_DODGE
 sta A_RETRY
 sta A_EVADE
@done:
 rts
@drop:
 lda V_MODE
 cmp #3
 bne :+
 lda #4
 sta N_heldButtons
 sta N_newlyPressedButtons
 rts
:
 lda V_WARNING
 bne @done
 ; Soft drop keeps early rounds moving while still respecting VFair.
 lda #4
 sta N_heldButtons
 jmp AHunt
@fallback:
 ; An unreachable target or blocked spawn is played where it is. Native
 ; descent and locking decide top-out; never delete an Auto-Classic piece.
 lda #3
 sta A_STATE
 jmp @drop

APlan:
 ; All four rotations fit vertically at row two, including the I.
 ; This is still inside the visible spawn/reaction interval.
 lda V_MODE
 cmp #3
 beq @classic
 lda #2
 sta N_tetriminoY
 jmp @heights
@classic:
 ; Advance through legal spawn rows instead of teleporting through a
 ; high stack. Failed staging leaves the native spawn/lock intact.
 jsr N_isPositionValid
 bne @blocked
@stage:
 lda N_tetriminoY
 cmp #2
 bcs @heights
 inc N_tetriminoY
 jsr N_isPositionValid
 beq @stage
 dec N_tetriminoY
@blocked:
 lda #3
 sta A_STATE
 rts
@heights:
 jsr AHeights
 lda V_REV
 sta A_REV
 lda N_currentPiece
 sta A_ROT
 sta A_FIRST
 lda #0
 sta A_X
 sta A_TICK
 lda #$FF
 sta A_BEST_HI
 sta A_BEST_LO
 lda M_X
 sec
 sbc #92
 lsr
 lsr
 lsr
 sta A_TARGET
 lda #1
 sta A_STATE
 lda #45
 sta V_WARNING
 rts

AHeights:
 ldx #0
@column:
 txa
 tay
 lda #0
 sta A_ROW
@row:
 lda $0400,y
 cmp #$EF
 bne @found
 inc A_ROW
 tya
 clc
 adc #10
 tay
 lda A_ROW
 cmp #20
 bne @row
@found:
 lda A_ROW
 sta A_HEIGHT,x
 inx
 cpx #10
 bne @column
 lda V_REV
 sta A_HEIGHT_REV
 rts

ACandidate:
 ; Compute the unobstructed vertical landing from the four column tops.
 lda A_ROT
 asl
 asl
 sta A_INDEX
 asl
 clc
 adc A_INDEX
 sta A_INDEX
 lda #22
 sta A_Y
 lda #4
 sta A_N
@land:
 ldx A_INDEX
 lda N_orientationTable+2,x
 clc
 adc A_X
 cmp #10
 jcs ANext
 tay
 lda A_HEIGHT,y
 sec
 sbc #1
 sec
 sbc N_orientationTable,x
 bmi @negative
 cmp A_Y
 bcs @nextMino
 sta A_Y
@nextMino:
 lda A_INDEX
 clc
 adc #3
 sta A_INDEX
 dec A_N
 bne @land
 jmp @simulate
@negative:
 jmp ANext
@simulate:
 lda A_Y
 cmp #2
 jcc ANext
 ldx #0
@copy:
 lda A_HEIGHT,x
 sta A_NEW_HEIGHT,x
 lda #0
 sta A_COUNTS,x
 inx
 cpx #10
 bne @copy
 lda A_ROT
 asl
 asl
 sta A_INDEX
 asl
 clc
 adc A_INDEX
 sta A_INDEX
 lda #0
 sta A_I
@put:
 ldx A_INDEX
 lda N_orientationTable,x
 clc
 adc A_Y
 cmp #20
 jcs ANext
 ldy A_I
 sta A_ROWS,y
 sta A_ROW
 tay
 lda N_multBy10Table,y
 clc
 adc A_X
 clc
 adc N_orientationTable+2,x
 tay
 ldx A_I
 tya
 sta A_CELLS,x
 ldx A_INDEX
 lda A_X
 clc
 adc N_orientationTable+2,x
 tax
 inc A_COUNTS,x
 lda A_ROW
 cmp A_NEW_HEIGHT,x
 bcs :+
 sta A_NEW_HEIGHT,x
:
 lda A_INDEX
 clc
 adc #3
 sta A_INDEX
 inc A_I
 lda A_I
 cmp #4
 bne @put
 lda #0
 sta A_SCORE_LO
 lda #8
 sta A_SCORE_HI
 ldx #0
@columns:
 lda #20
 sec
 sbc A_NEW_HEIGHT,x
 asl
 jsr AAdd
 lda A_HEIGHT,x
 sec
 sbc A_NEW_HEIGHT,x
 sec
 sbc A_COUNTS,x
 sta A_N
 beq @nextColumn
@holes:
 lda #20
 jsr AAdd
 dec A_N
 bne @holes
@nextColumn:
 inx
 cpx #10
 bne @columns
 ; Adjacent safe surfaces must be within a held Mario jump (32 pixels).
 ; A one-column Tetris well at the right edge does not block the route.
 ldx #0
@rough:
 lda A_NEW_HEIGHT,x
 sec
 sbc A_NEW_HEIGHT+1,x
 jsr AAbs
 sta A_TEMP
 lda V_MODE
 cmp #3
 beq @classicRough
 lda A_TEMP
 cmp #5
 bcc @smooth
 sta A_TEMP
 cpx #8
 beq @smooth
 ; Mario can remove terrain while a round is in progress. An existing
 ; cliff must not invalidate every candidate forever: allow placements
 ; that leave it unchanged or repair it, but never make it steeper.
 lda A_HEIGHT,x
 sec
 sbc A_HEIGHT+1,x
 jsr AAbs
 cmp A_TEMP
 jcc ANext
 lda A_TEMP
@smooth:
 asl
 jsr AAdd
 inx
 cpx #9
 bne @rough
 jmp @well
@classicRough:
 lda A_TEMP
 jmp @smooth
@well:
 ; Reserve the rightmost well for a vertical I and four-line clears.
 lda #20
 sec
 sbc A_NEW_HEIGHT+9
 asl
 asl
 jsr AAdd
 ; Only rows touched by these four minos can become complete. Reading
 ; them directly avoids copying/scanning all 200 cells every candidate.
 lda #0
 sta A_LINES
 sta A_I
@line:
 ldx A_I
 lda A_ROWS,x
 sta A_ROW
 ldy #0
@duplicate:
 cpy A_I
 beq @newRow
 cmp A_ROWS,y
 beq @lineNext
 iny
 bne @duplicate
@newRow:
 tay
 lda N_multBy10Table,y
 tay
 lda #10
 sta A_N
@cell:
 lda $0400,y
 cmp #$EF
 bne @filled
 ldx #0
 tya
@newCell:
 cmp A_CELLS,x
 beq @filled
 inx
 cpx #4
 bne @newCell
 jmp @lineNext
@filled:
 iny
 dec A_N
 bne @cell
 ldx A_LINES
 lda A_ROW
 sta A_COMPLETE,x
 inc A_LINES
@lineNext:
 inc A_I
 lda A_I
 cmp #4
 bne @line
 lda A_LINES
 beq @target
 lda V_MODE
 cmp #3
 beq @classicClear
 jsr APostFair
 cmp #0
 jeq ANext
 lda A_LINES
 cmp #4
 beq @tetris
 tax
 beq @target
@smallClear:
 lda #64
 jsr AAdd
 dex
 bne @smallClear
 jmp @target
@tetris:
 lda #64
 jsr ASub
 lda #160
 jsr ASub
 jmp @target
@classicClear:
 ; Take smaller clears to recover a dangerous stack, while favoring a
 ; Tetris strongly when it is available. No Mario-related safety veto.
 ldx A_LINES
@classicLine:
 lda #64
 jsr ASub
 dex
 bne @classicLine
 lda A_LINES
 cmp #4
 bne @target
 lda #160
 jsr ASub
@target:
 lda V_MODE
 cmp #3
 beq @compare
 ; Levels 0..9 play Tetris. Hunt pressure starts at ten and grows.
 lda A_X
 sec
 sbc A_TARGET
 jsr AAbs
 asl
 sta A_TEMP
 lda N_levelNumber
 sec
 sbc #9
 bmi @compare
 cmp #25
 bcc :+
 lda #24
:
 tax
 beq @compare
@aim:
 lda A_TEMP
 jsr AAdd
 dex
 bne @aim
@compare:
 lda A_SCORE_HI
 cmp A_BEST_HI
 bcc @best
 bne ANext
 lda A_SCORE_LO
 cmp A_BEST_LO
 bcs ANext
@best:
 lda A_SCORE_LO
 sta A_BEST_LO
 lda A_SCORE_HI
 sta A_BEST_HI
 lda A_ROT
 sta A_BEST_ROT
 lda A_X
 sta A_BEST_X
ANext:
 inc A_X
 lda A_X
 cmp #10
 bcc @done
 lda #0
 sta A_X
 lda A_ROT
 asl
 tax
 lda N_rotationTable+1,x
 sta A_ROT
 cmp A_FIRST
 bne @done
 lda #2
 sta A_STATE
@done:
 rts
AAbs:
 bpl :+
 eor #$FF
 clc
 adc #1
:
 rts
AAdd:
 clc
 adc A_SCORE_LO
 sta A_SCORE_LO
 bcc :+
 inc A_SCORE_HI
:
 rts
ASub:
 sta A_TEMP
 lda A_SCORE_LO
 sec
 sbc A_TEMP
 sta A_SCORE_LO
 bcs :+
 dec A_SCORE_HI
:
 rts

; A line clear can remove the only support over a buried hole. Check the
; resulting board as well as the landing skyline, before accepting it.
APostFair:
 ldx #19
 lda #0
@mask:
 sta A_CLEAR_MASK,x
 dex
 bpl @mask
 ldx #0
@markedRow:
 ldy A_COMPLETE,x
 lda #1
 sta A_CLEAR_MASK,y
 inx
 cpx A_LINES
 bne @markedRow
 ldx #3
@markedCell:
 ldy A_CELLS,x
 lda #1
 sta A_SHADOW,y
 dex
 bpl @markedCell
 lda #0
 sta A_COL
@column:
 ldx A_COL
 lda A_NEW_HEIGHT,x
 clc
 adc A_LINES
 sta A_TEMP
 lda A_NEW_HEIGHT,x
 tay
 lda A_CLEAR_MASK,y
 bne @lostTop
 lda A_TEMP
 jmp @height
@lostTop:
 tya
 clc
 adc #1
 sta A_ROW
 cmp #20
 beq @emptyColumn
 tay
 lda N_multBy10Table,y
 clc
 adc A_COL
 sta A_INDEX
@row:
 ldy A_ROW
 lda A_CLEAR_MASK,y
 bne @nextRow
 ldy A_INDEX
 lda $0400,y
 cmp #$EF
 bne @found
 lda A_SHADOW,y
 cmp #1
 beq @found
 inc A_TEMP
@nextRow:
 lda A_INDEX
 clc
 adc #10
 sta A_INDEX
 inc A_ROW
 lda A_ROW
 cmp #20
 bne @row
@emptyColumn:
 lda #20
 bne @height
@found:
 lda A_TEMP
@height:
 ldx A_COL
 sta A_POST_HEIGHT,x
 inc A_COL
 lda A_COL
 cmp #9
 bne @column
 ldx #0
@edge:
 lda A_POST_HEIGHT,x
 sec
 sbc A_POST_HEIGHT+1,x
 jsr AAbs
 cmp #5
 bcc @nextEdge
 sta A_TEMP
 lda A_HEIGHT,x
 sec
 sbc A_HEIGHT+1,x
 jsr AAbs
 cmp A_TEMP
 bcc @unsafe
@nextEdge:
 inx
 cpx #8
 bne @edge
 lda #1
 bne @clean
@unsafe:
 lda #0
@clean:
 pha
 ldx #3
@unmark:
 ldy A_CELLS,x
 lda #0
 sta A_SHADOW,y
 dex
 bpl @unmark
 pla
 rts


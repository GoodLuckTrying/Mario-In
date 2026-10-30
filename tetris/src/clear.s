.export VClearShow,VClearStep,VResume
VClearShow:
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
 bit $2002
 lda #$23
 sta $2006
 lda #$C0
 sta $2006
 ldx #64
 lda #0
@palette:
 sta $2007
 dex
 bne @palette
 jsr N_bulkCopyToPpu
 .addr ClearText
 lda #$21
 ldx #$56
 jsr ClearAddress
 lda V_CLEARED_LEVEL
 jsr ClearNumber
 lda #$21
 ldx #$96
 jsr ClearAddress
 lda V_CLEAR_GAIN
 jsr ClearNumber
 lda #$21
 ldx #$D6
 jsr ClearAddress
 lda N_levelNumber
 jsr ClearNumber
 lda #$22
 ldx #$15
 jsr ClearAddress
 lda N_lines+1
 and #15
 sta $2007
 lda N_lines
 jsr N_twoDigsToPPU
 lda #$22
 ldx #$52
 jsr ClearAddress
 lda N_score+2
 jsr N_twoDigsToPPU
 lda N_score+1
 jsr N_twoDigsToPPU
 lda N_score
 jsr N_twoDigsToPPU
 jsr N_waitForVBlankAndEnableNmi
 jsr N_updateAudioWaitForNmiAndResetOamStaging
 jmp N_updateAudioWaitForNmiAndEnablePpuRendering
ClearAddress:
 bit $2002
 sta $2006
 stx $2006
 rts
ClearNumber:
 ldx #0
@tens:
 cmp #10
 bcc @digits
 sec
 sbc #10
 inx
 bne @tens
@digits:
 stx $2007
 sta $2007
 rts
ClearText:
 .byte $20,$CB,.strlen("ROUND CLEAR"),"ROUND CLEAR"
 .byte $21,$09,.strlen("MARIO ESCAPED"),"MARIO ESCAPED"
 .byte $21,$45,.strlen("CLEARED LEVEL"),"CLEARED LEVEL"
 .byte $21,$85,.strlen("TETRIS GAINS"),"TETRIS GAINS"
 .byte $21,$C5,.strlen("NEXT LEVEL"),"NEXT LEVEL"
 .byte $22,$05,.strlen("TOTAL LINES"),"TOTAL LINES"
 .byte $22,$45,.strlen("SCORE"),"SCORE"
 .byte $22,$C5,.strlen("A OR START TO CONTINUE"),"A OR START TO CONTINUE"
 .byte $23,$09,.strlen("AUTO CONTINUE"),"AUTO CONTINUE"
 .byte $FF
VClearStep:
 lda N_newlyPressedButtons_player1
 sta V_CLEAR_INPUT
 and #$EF
 sta N_newlyPressedButtons_player1
 dec V_CLEAR
 beq VResume
 lda V_CLEAR
 cmp #120
 bcs @wait
 lda V_CLEAR_INPUT
 and #$90
 bne VResume
@wait:
 rts
VResume:
 lda #1
 sta V_CLEAR
 ; Rebuild the native HUD without resetting cumulative progress or the
 ; selected opponent. The background helper normally copies startLevel.
 lda N_player1_startLevel
 pha
 lda N_gameModeState
 pha
 lda N_levelNumber
 sta N_player1_startLevel
 jsr N_gameModeState_initGameBackground
 pla
 sta N_gameModeState
 pla
 sta N_player1_startLevel
 lda #0
 sta V_CLEAR
 sta N_fallTimer
 sta N_vramRow
 sta N_player1_vramRow
 sta V_CLOCK
 lda #1
 sta V_HUD
 lda #3
 sta N_renderMode
 lda #$47
 sta N_outOfDateRenderFlags
 lda N_heldButtons_player1
 sta M_PREV
 lda N_newlyPressedButtons_player1
 and #$6F
 sta N_newlyPressedButtons_player1
 rts

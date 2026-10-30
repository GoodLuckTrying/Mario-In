MarioControlGate:
 LDA #PRGBank_6_7
 JSR ChangeMappedPRGBank
 JSR MarioControl
 LDA #PRGBank_0_1
 JMP ChangeMappedPRGBank
MarioGravityGate:
 LDA QuicksandDepth
 CMP #2
 BCS MarioGravityNative
 LDA #PRGBank_6_7
 JSR ChangeMappedPRGBank
 JSR MarioGravity
 LDA #PRGBank_0_1
 JMP ChangeMappedPRGBank
MarioGravityNative:
 JMP PlayerGravity
MarioApplyYGate:
 LDA #PRGBank_6_7
 JSR ChangeMappedPRGBank
 JSR MarioApplyY
 LDA #PRGBank_0_1
 JSR ChangeMappedPRGBank
 LDX #$0A
 LDA #0
 RTS
MarioApplyXGate:
 LDA #PRGBank_6_7
 JSR ChangeMappedPRGBank
 JSR MarioApplyX
 LDA #PRGBank_0_1
 JSR ChangeMappedPRGBank
 LDX #0
 LDA #0
 RTS
MarioReset:
 LDA #0
 LDX #$7F
MarioReset_Loop:
 STA $7E00,X
 DEX
 BPL MarioReset_Loop
 LDA #$70
 STA M_GRAVITY
 STA M_FALL_FORCE
 LDA #$FF
 STA M_PALETTE
 RTS

; Only the player's sprite palette is updated. Native enemy and
; background palettes are untouched.
MarioPaletteNMI:
 LDA GameMilestoneCounter
 CMP #1
 BNE MarioPaletteNMI_Exit
 LDX #0
 LDA CurrentCharacter
 BEQ MarioPaletteNMI_Size
 LDX #6
MarioPaletteNMI_Size:
 LDA PlayerCurrentSize
 BEQ MarioPaletteNMI_Write
 INX
 INX
 INX
MarioPaletteNMI_Write:
 ; The native renderer signaled a full crouch charge by alternating
 ; palettes. Use bright player shades at the same cadence so the SMB
 ; artwork flashes without borrowing an enemy's colors.
 LDA CrouchJumpTimer
 CMP #60
 BCC MarioPaletteNMI_Selected
 LDA PlayerState
 BNE MarioPaletteNMI_Selected
 LDA PlayerInAir
 BNE MarioPaletteNMI_Selected
 LDA byte_RAM_10
 AND #1
 BEQ MarioPaletteNMI_Selected
 TXA
 CLC
 ADC #12
 TAX
MarioPaletteNMI_Selected:
 ; A delayed native palette buffer can overwrite these colors after
 ; ApplyPalette invalidates the old cache. Reassert the three player
 ; shades after every gameplay upload, even when size is unchanged.
 STX M_PALETTE
 BIT PPUSTATUS
 LDA #$3F
 STA PPUADDR
 LDA #$11
 STA PPUADDR
 LDA MarioColors,X
 STA PPUDATA
 LDA MarioColors+1,X
 STA PPUDATA
 LDA MarioColors+2,X
 STA PPUDATA
MarioPaletteNMI_Exit:
 RTS
MarioColors:
 .db $37,$27,$16,$16,$27,$18
 .db $37,$27,$19,$30,$27,$19
 ; Charge-ready highlights, indexed by the same brother/form offsets.
 .db $30,$37,$27,$26,$37,$28
 .db $30,$37,$29,$37,$37,$29

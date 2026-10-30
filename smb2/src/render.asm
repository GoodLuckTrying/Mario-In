MarioPrepareRender:
 LDA PlayerDucking
 ORA PlayerCurrentSize
 STA PlayerHitbox
 RTS
MarioRenderAfterObjects:
 LDA PlayerInRocket
 BNE MarioRenderAfterObjects_Exit
 JSR SetPlayerScreenPosition
 JSR RenderPlayer
MarioRenderAfterObjects_Exit:
 RTS
RenderPlayer:
 JSR MarioPrepareRender
 ; Derive a complete SMB pose bank every frame. CHR selection itself
 ; remains in the original vblank-only MMC3 uploader.
 LDY #23
 LDA PlayerState
 CMP #PlayerState_Dying
 BNE MarioPose_Climb
 LDY #22
 JMP MarioPose_Set
MarioPose_Climb:
 CMP #PlayerState_Climbing
 BNE MarioPose_Duck
 LDA PlayerXVelocity
 ORA PlayerYVelocity
 BEQ MarioPose_ClimbFrame
 INC M_CLIMB_PHASE
MarioPose_ClimbFrame:
 LDA M_CLIMB_PHASE
 LSR A
 LSR A
 LSR A
 AND #1
 CLC
 ADC #8
 TAY
 LDA PlayerCurrentSize
 BNE MarioPose_ClimbSmall
 JMP MarioPose_Set
MarioPose_ClimbSmall:
 TYA
 CLC
 ADC #12
 TAY
 JMP MarioPose_Set
MarioPose_Duck:
 LDA PlayerDucking
 BEQ MarioPose_Air
 LDY #10
 LDA PlayerCurrentSize
 BEQ MarioPose_Set
 LDY #23
 BNE MarioPose_Set
MarioPose_Air:
 LDA M_THROW
 BEQ MarioPose_Pull
 DEC M_THROW
 LDY #11
 JMP MarioPose_Set
MarioPose_Pull:
 LDA PlayerAnimationFrame
 CMP #SpriteAnimation_Pulling
 BEQ MarioPose_Carry
 LDA HoldingItem
 BNE MarioPose_Carry
 LDA PlayerInAir
 BEQ MarioPose_Walk
 LDY #4
 JMP MarioPose_Size
MarioPose_Carry:
 LDY #11
 LDA PlayerCurrentSize
 BEQ MarioPose_Set
 LDY #23
 BNE MarioPose_Set
MarioPose_Walk:
 LDA PlayerXVelocity
 BNE MarioPose_Walking
 LDA #0
 STA M_WALK_TIMER
 STA M_WALK_FRAME
 LDY #24
 LDA PlayerCurrentSize
 BEQ MarioPose_Set
 LDY #23
 BNE MarioPose_Set
MarioPose_Walking:
 LDA M_WALK_TIMER
 BEQ MarioPose_NextStep
 DEC M_WALK_TIMER
 JMP MarioPose_WalkFrame
MarioPose_NextStep:
 LDA M_ANIM_SET
 STA M_WALK_TIMER
 INC M_WALK_FRAME
 LDA M_WALK_FRAME
 CMP #3
 BCC MarioPose_WalkFrame
 LDA #0
 STA M_WALK_FRAME
MarioPose_WalkFrame:
 LDY M_WALK_FRAME
MarioPose_Size:
 LDA PlayerCurrentSize
 BEQ MarioPose_Set
 TYA
 CLC
 ADC #12
 TAY
MarioPose_Set:
 STY M_POSE
 TYA
 CLC
 ADC #$80
 STA SpriteCHR1
 LDA PlayerState
 CMP #PlayerState_ChangingSize
 BEQ MarioDraw_Start
 LDA DamageInvulnTime
 BEQ MarioDraw_Start
 LDA byte_RAM_10
 AND #2
 BEQ MarioDraw_Exit
MarioDraw_Start:
 LDA PlayerScreenYLo
 STA M_Y
 LDA PlayerScreenYHi
 STA M_SCRATCH
 LDA #0
 STA M_I
 STA M_ATTR
 LDA PlayerDirection
 BNE MarioDraw_Loop
 LDA #$40
 STA M_ATTR
MarioDraw_Loop:
 LDY M_I
 CPY #2
 BCS MarioDraw_Visible
 LDA PlayerCurrentSize
 BNE MarioDraw_Next
MarioDraw_Visible:
 LDA MarioDraw_Tiles,Y
 STA M_TILE
 LDA M_ATTR
 BEQ MarioDraw_Tile
 LDA M_TILE
 EOR #2
 STA M_TILE
MarioDraw_Tile:
 LDA M_Y
 CLC
 ADC MarioDraw_Y,Y
 STA M_TEMP
 LDA M_SCRATCH
 ADC #0
 BNE MarioDraw_Next
 LDA M_TEMP
 CMP #$EF
 BCS MarioDraw_Next
 LDX MarioDraw_Slots,Y
 STA SpriteDMAArea,X
 LDA M_TILE
 STA SpriteDMAArea+1,X
 LDA M_ATTR
 ORA PlayerAttributes
 STA SpriteDMAArea+2,X
 LDA PlayerScreenX
 CLC
 ADC MarioDraw_X,Y
 BCS MarioDraw_Next
 STA SpriteDMAArea+3,X
MarioDraw_Next:
 INC M_I
 LDA M_I
 CMP #4
 BNE MarioDraw_Loop
MarioDraw_Exit:
 RTS
MarioDraw_Tiles:
 .db 0,2,4,6
MarioDraw_X:
 .db 0,8,0,8
MarioDraw_Y:
 .db 0,0,16,16
MarioDraw_Slots:
 .db $20,$24,$28,$2C

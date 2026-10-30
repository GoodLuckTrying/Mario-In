; Executed from the previously empty second half of PRG bank pair 6/7.
MarioControl:
 LDA PlayerInAir
 STA M_STATE
 LDA #1
 STA M_AREA_TYPE
 LDA #8
 STA M_ENGINE_MODE
 LDA #3
 STA M_COLL_DIR
 LDA Player1JoypadHeld
 STA M_HELD
 LDA M_PREV_HELD
 STA M_OLD_HELD
 LDA M_HELD
 STA M_PREV_HELD
 LDA M_HELD
 AND #3
 STA M_INPUT_DIR
 LDA PlayerDirection
 EOR #1
 CLC
 ADC #1
 STA M_FACING
 LDA M_MOVING_DIR
 BNE MarioControl_DirectionReady
 LDA M_FACING
 STA M_MOVING_DIR
MarioControl_DirectionReady:
 LDA M_RUNNING_TIMER
 BEQ MarioControl_TimerDone
 DEC M_RUNNING_TIMER
MarioControl_TimerDone:
 LDA PlayerXVelocity
 BNE MarioControl_Speed
 LDA M_LAST_X
 BEQ MarioControl_Speed
 LDA #0
 STA M_SMB_X_FORCE
MarioControl_Speed:
MarioControl_Duck:
 LDA PlayerInAir
 BNE MarioControl_JumpTest
 LDA #0
 STA PlayerDucking
 LDA M_HELD
 AND #4
 BEQ MarioControl_JumpTest
 LDA M_INPUT_DIR
 BEQ MarioControl_DuckCharge
 LDA #0
 STA M_INPUT_DIR
 BEQ MarioControl_JumpTest
MarioControl_DuckCharge:
 INC PlayerDucking
 LDA #SpriteAnimation_Ducking
 STA PlayerAnimationFrame
 LDA CrouchJumpTimer
 CMP #60
 BCS MarioControl_JumpTest
 INC CrouchJumpTimer
MarioControl_JumpTest:
 LDA PlayerInAir
 BNE MarioControl_X
 LDA Player1JoypadPress
 BMI MarioControl_JumpPressed
 JSR MarioControl_ChargeReset
 JMP MarioControl_X
MarioControl_JumpPressed:
 LDA QuicksandDepth
 CMP #2
 BCC MarioControl_JumpNormal
 LDA #$E0
 STA PlayerYVelocity
 JMP MarioControl_JumpStart
MarioControl_JumpNormal:
 LDY #0
 LDA M_SMB_X_ABS
 CMP #9
 BCC MarioControl_JumpForce
 INY
 CMP #16
 BCC MarioControl_JumpForce
 INY
 CMP #25
 BCC MarioControl_JumpForce
 INY
 CMP #28
 BCC MarioControl_JumpForce
 INY
MarioControl_JumpForce:
 LDA MarioJumpFall,Y
 STA M_FALL_FORCE
 LDA MarioJumpHold,Y
 STA M_GRAVITY
 LDA MarioJumpSpeed,Y
 STA M_VY
 LDA MarioJumpFraction,Y
 STA M_VF
 LDA CrouchJumpTimer
 CMP #60
 BCC MarioControl_JumpEncode
 ; Retain SMB2's charged jump for level geometry and hidden routes.
 LDA #$FA
 STA M_VY
 LDA #$80
 STA M_VF
MarioControl_JumpEncode:
 JSR MarioEncodeY
MarioControl_JumpStart:
 LDA #0
 STA PlayerYSubpixel
 STA CrouchJumpTimer
 LDA #1
 STA PlayerInAir
 STA M_STATE
 LDA PlayerYLo
 STA M_ORIGIN
 LDA #SpriteAnimation_Jumping
 STA PlayerAnimationFrame
 LDA #SoundEffect2_Jump
 STA SoundEffectQueue2
MarioControl_X:
 JSR X_Physics
 LDA PlayerInAir
 BNE MarioControl_AirInput
 JSR GetPlayerAnimSpeed
 LDA M_INPUT_DIR
 BEQ MarioControl_Friction
 STA M_FACING
 AND #1
 STA PlayerDirection
 LDA M_INPUT_DIR
 JMP MarioControl_Friction
MarioControl_AirInput:
 LDA M_INPUT_DIR
 BEQ MarioControl_Position
MarioControl_Friction:
 JSR ImposeFriction
MarioControl_Position:
 LDA PlayerXVelocity
 BEQ MarioControl_Sand
 LDY #1
 CMP #$80
 BCC MarioControl_MovingRight
 INY
MarioControl_MovingRight:
 STY M_MOVING_DIR
MarioControl_Sand:
 LDA QuicksandDepth
 CMP #2
 BCC MarioControl_Exit
 LDA PlayerXVelocity
 BMI MarioControl_SandLeft
 CMP #5
 BCC MarioControl_Exit
 LDA #4
 BNE MarioControl_SandStore
MarioControl_SandLeft:
 CMP #$FC
 BCS MarioControl_Exit
 LDA #$FC
MarioControl_SandStore:
 STA PlayerXVelocity
MarioControl_Exit:
 LDA PlayerXVelocity
 STA M_LAST_X
 RTS
MarioControl_ChargeReset:
 LDA CrouchJumpTimer
 CMP #60
 BCS MarioControl_ChargeDone
 LDA Player1JoypadHeld
 AND #4
 BNE MarioControl_ChargeDone
 LDA #0
 STA CrouchJumpTimer
MarioControl_ChargeDone:
 RTS

MarioGravity:
 ; Prepare the native collision probes without advancing velocity early.
 ; The actual position step and SMB gravity run together after collisions.
 JSR MarioSyncY
 LDA PlayerInAir
 BNE MarioGravity_Ready
 LDA #0
 STA M_VY
 STA M_VF
 LDA PlayerYAcceleration
 BNE MarioGravity_Ready
 LDA #0
 STA PlayerYSubpixel
MarioGravity_Ready:
 LDA #1
 STA M_PHYSICS_READY
 JMP MarioEncodeY
MarioSyncY:
 LDA M_PHYSICS_READY
 BEQ MarioGravity_Import
 LDA PlayerYVelocity
 CMP M_LAST_Y
 BEQ MarioGravity_Synced
MarioGravity_Import:
 LDA PlayerYVelocity
 ; Native ceilings, landings, stomps, knockback, vines and transitions
 ; may change Y velocity. Import that result before applying gravity.
 STA M_TEMP
 ASL A
 ASL A
 ASL A
 ASL A
 STA M_VF
 LDA M_TEMP
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 STA M_VY
MarioGravity_Synced:
 RTS

MarioApplyY:
 JSR MarioSyncY
 LDA PlayerInAir
 BNE MarioApplyY_Air
 LDA #0
 STA M_VY
 STA M_VF
 LDA PlayerYAcceleration
 BNE MarioApplyY_Integrate
 LDA #0
 STA PlayerYSubpixel
 JMP MarioEncodeY
MarioApplyY_Air:
 LDA M_VY
 BPL MarioApplyY_Fall
 LDA M_HELD
 AND M_OLD_HELD
 AND #$80
 BNE MarioApplyY_Integrate
 LDA M_ORIGIN
 SEC
 SBC PlayerYLo
 CMP #1
 BCC MarioApplyY_Integrate
MarioApplyY_Fall:
 LDA M_FALL_FORCE
 STA M_GRAVITY
MarioApplyY_Integrate:
 ; Native moving supports contribute an extra delta, not persistent speed.
 LDA PlayerYAcceleration
 ASL A
 ASL A
 ASL A
 ASL A
 CLC
 ADC M_VF
 STA M_DELTA_FRAC
 PHP
 LDA PlayerYAcceleration
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 STA M_DELTA_WHOLE
 PLP
 LDA M_VY
 ADC M_DELTA_WHOLE
 STA M_DELTA_WHOLE
 CMP #$80
 LDY #0
 BCC MarioApplyY_Sign
 DEY
MarioApplyY_Sign:
 STY M_SIGN
 LDA PlayerYSubpixel
 CLC
 ADC M_DELTA_FRAC
 STA PlayerYSubpixel
 LDA M_DELTA_WHOLE
 ADC PlayerYLo
 STA PlayerYLo
 LDA PlayerYHi
 ADC M_SIGN
 STA PlayerYHi
 LDA #0
 STA PlayerYAcceleration
 LDA PlayerInAir
 BEQ MarioEncodeY
 ; SMB1 advances gravity AFTER applying the old velocity to position.
 LDA M_VF
 CLC
 ADC M_GRAVITY
 STA M_VF
 LDA M_VY
 ADC #0
 STA M_VY
 BMI MarioEncodeY
 CMP #4
 BCC MarioEncodeY
 LDA M_VF
 CMP #$80
 BCC MarioEncodeY
 LDA #4
 STA M_VY
 LDA #0
 STA M_VF
MarioEncodeY:
 LDA M_VY
 ASL A
 ASL A
 ASL A
 ASL A
 STA M_TEMP
 LDA M_VF
 LSR A
 LSR A
 LSR A
 LSR A
 ORA M_TEMP
 STA PlayerYVelocity
 STA M_LAST_Y
 RTS

MarioApplyX:
 LDA PlayerXVelocity
 CLC
 ADC PlayerXAcceleration
 STA M_TEMP
 ASL A
 ASL A
 ASL A
 ASL A
 CLC
 ADC PlayerXSubpixel
 STA PlayerXSubpixel
 PHP
 LDA M_TEMP
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 CMP #$80
 ROR A
 STA M_DELTA_WHOLE
 CMP #$80
 LDY #0
 BCC MarioApplyX_Sign
 DEY
MarioApplyX_Sign:
 STY M_SIGN
 PLP
 LDA M_DELTA_WHOLE
 ADC PlayerXLo
 STA PlayerXLo
 LDA PlayerXHi
 ADC M_SIGN
 STA PlayerXHi
 LDA #0
 STA PlayerXAcceleration
 LDA IsHorizontalLevel
 BNE MarioApplyX_Exit
 LDA #0
 STA PlayerXHi
MarioApplyX_Exit:
 LDA #0
 RTS
MarioJumpHold:
 .db $20,$20,$1E,$28,$28
MarioJumpFall:
 .db $70,$70,$60,$90,$90
MarioJumpSpeed:
 .db $FC,$FC,$FC,$FB,$FB
MarioJumpFraction:
 .db $00,$00,$00,$00,$00
.include "src/mario-land.asm"

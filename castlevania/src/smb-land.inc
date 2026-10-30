; Normal-land SMB branches copied from the supplied SMB disassembly.
Player_State = M_PHYS_STATE
Player_X_Speed = M_SMB_X_SPEED
Player_X_MoveForce = M_SMB_X_FORCE
Player_XSpeedAbsolute = M_SMB_X_ABS
RunningSpeed = M_RUNNING_SPEED
RunningTimer = M_RUNNING_TIMER
PlayerFacingDir = M_FACING
Player_MovingDir = M_MOVING_DIR
MaximumLeftSpeed = M_MAX_LEFT
MaximumRightSpeed = M_MAX_RIGHT
FrictionAdderLow = M_FRICTION_LO
FrictionAdderHigh = M_FRICTION_HI
PlayerAnimTimerSet = M_ANIM_SET
AreaType = M_AREA_TYPE
GameEngineSubroutine = M_ENGINE_MODE
Left_Right_Buttons = M_INPUT_DIR
A_B_Buttons = M_HELD
SavedJoypadBits = M_HELD
Player_CollisionBits = M_COLL_DIR
B_Button = $40
MaxLeftXSpdData:
      .byte $d8, $e8, $f0
MaxRightXSpdData:
      .byte $28, $18, $10
      .byte $0c
FrictionData:
      .byte $e4, $98, $d0
X_Physics: ldy #$00
           sty $00
           lda Player_State
           beq ProcPRun
           lda Player_XSpeedAbsolute
           cmp #$19
           bcs GetXPhy
           bcc ChkRFast
ProcPRun:  iny
           lda AreaType
           beq ChkRFast
           dey
           lda Left_Right_Buttons
           cmp Player_MovingDir
           bne ChkRFast
           lda A_B_Buttons
           and #B_Button
           bne SetRTmr
           lda RunningTimer
           bne GetXPhy
ChkRFast:  iny
           inc $00
           lda RunningSpeed
           bne FastXSp
           lda Player_XSpeedAbsolute
           cmp #$21
           bcc GetXPhy
FastXSp:   inc $00
           jmp GetXPhy
SetRTmr:   lda #$0a
           sta RunningTimer
GetXPhy:   lda MaxLeftXSpdData,y
           sta MaximumLeftSpeed
           lda GameEngineSubroutine
           cmp #$07
           bne GetXPhy2
           ldy #$03
GetXPhy2:  lda MaxRightXSpdData,y
           sta MaximumRightSpeed
           ldy $00
           lda FrictionData,y
           sta FrictionAdderLow
           lda #$00
           sta FrictionAdderHigh
           lda PlayerFacingDir
           cmp Player_MovingDir
           beq ExitPhy
           asl FrictionAdderLow
           rol FrictionAdderHigh
ExitPhy:   rts
PlayerAnimTmrData:
      .byte $02, $04, $07
GetPlayerAnimSpeed:
            ldy #$00
            lda Player_XSpeedAbsolute
            cmp #$1c
            bcs SetRunSpd
            iny
            cmp #$0e
            bcs ChkSkid
            iny
ChkSkid:    lda SavedJoypadBits
            and #%01111111
            beq SetAnimSpd
            and #$03
            cmp Player_MovingDir
            bne ProcSkid
            lda #$00
SetRunSpd:  sta RunningSpeed
            jmp SetAnimSpd
ProcSkid:   lda Player_XSpeedAbsolute
            cmp #$0b
            bcs SetAnimSpd
            lda PlayerFacingDir
            sta Player_MovingDir
            lda #$00
            sta Player_X_Speed
            sta Player_X_MoveForce
SetAnimSpd: lda PlayerAnimTmrData,y
            sta PlayerAnimTimerSet
            rts
ImposeFriction:
           and Player_CollisionBits
           cmp #$00
           bne JoypFrict
           lda Player_X_Speed
           beq SetAbsSpd
           bpl RghtFrict
           bmi LeftFrict
JoypFrict: lsr
           bcc RghtFrict
LeftFrict: lda Player_X_MoveForce
           clc
           adc FrictionAdderLow
           sta Player_X_MoveForce
           lda Player_X_Speed
           adc FrictionAdderHigh
           sta Player_X_Speed
           cmp MaximumRightSpeed
           bmi XSpdSign
           lda MaximumRightSpeed
           sta Player_X_Speed
           jmp SetAbsSpd
RghtFrict: lda Player_X_MoveForce
           sec
           sbc FrictionAdderLow
           sta Player_X_MoveForce
           lda Player_X_Speed
           sbc FrictionAdderHigh
           sta Player_X_Speed
           cmp MaximumLeftSpeed
           bpl XSpdSign
           lda MaximumLeftSpeed
           sta Player_X_Speed
XSpdSign:  cmp #$00
           bpl SetAbsSpd
           eor #$ff
           clc
           adc #$01
SetAbsSpd: sta Player_XSpeedAbsolute
           rts

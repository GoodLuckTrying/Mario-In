.INCLUDE "mario-vars.inc"
.IMPORT GetCollidableTileStill,SwitchBank,PlayAreaColumnAddrs
.EXPORT MarioFireUpdate,MarioFireRender
.SEGMENT "MARIO_CODE"
MarioFireUpdate:
 LDA RoomId
 CMP M_ROOM
 BNE @Reset
 LDA GameMode
 CMP M_MODE
 BEQ @Input
@Reset:
 LDA #0
 STA M_TTL
 STA M_TTL+1
 LDA RoomId
 STA M_ROOM
 LDA GameMode
 STA M_MODE
@Input:
 LDA ObjState
 AND #$C0
 ORA LinkParalyzed
 ORA ItemLiftTimer
 BNE @Move
 LDA ButtonsPressed
 AND #$80
 BEQ @Move
 LDX #1
@Find:
 LDA M_TTL,X
 BEQ @Spawn
 DEX
 BPL @Find
 BMI @Move
@Spawn:
 LDA #96
 STA M_TTL,X
 LDA #0
 STA M_PHASE,X
 STA M_FRAC,X
 LDA ObjDir
 STA M_DIR,X
 LDA ObjX
 CLC
 ADC #4
 STA M_X,X
 LDA ObjY
 CLC
 ADC #4
 STA M_Y,X
 ; The native sword sound is also a short fireball throw cue.
 LDA EffectRequest
 ORA #1
 STA EffectRequest
@Move:
 LDX #1
@Loop:
 STX M_I
 LDA M_TTL,X
 BNE :+
 JMP @Next
:
 DEC M_TTL,X
 BNE :+
 JMP @Next
:
 LDY M_PHASE,X
 LDA MarioBounceSpeed,Y
 LSR
 LSR
 LSR
 LSR
 STA M_STEP
 LDA MarioBounceSpeed,Y
 ASL
 ASL
 ASL
 ASL
 CLC
 ADC M_FRAC,X
 STA M_FRAC,X
 LDA M_STEP
 ADC #0
 STA M_STEP
 INY
 CPY #20
 BCC :+
 LDY #0
:
 TYA
 STA M_PHASE,X
 LDA M_DIR,X
 CMP #1
 BEQ @Right
 CMP #2
 BEQ @Left
 CMP #4
 BEQ @Down
 LDA M_Y,X
 SEC
 SBC M_STEP
 BCC @Destroy
 STA M_Y,X
 JMP @Bounds
@Down:
 LDA M_Y,X
 CLC
 ADC M_STEP
 BCS @Destroy
 STA M_Y,X
 JMP @Bounds
@Left:
 LDA M_X,X
 SEC
 SBC M_STEP
 BCC @Destroy
 STA M_X,X
 JMP @Bounds
@Right:
 LDA M_X,X
 CLC
 ADC M_STEP
 BCS @Destroy
 STA M_X,X
@Bounds:
 LDA M_X,X
 CMP #8
 BCC @Destroy
 CMP #$F0
 BCS @Destroy
 LDA M_Y,X
 CMP #$40
 BCC @Destroy
 CMP #$E8
 BCS @Destroy
 JSR MarioFireTerrain
 BCS @Destroy
 JMP @Next
@Destroy:
 LDA #0
 STA M_TTL,X
@Next:
 DEX
 BMI @Exit
 JMP @Loop
@Exit:
 RTS

; Query the tile under the 8x8 shot's center without borrowing any object
; slot. The native layout is column-major, with 22 rows per column.
MarioFireTerrain:
 LDA M_X,X
 CLC
 ADC #4
 AND #$F8
 LSR
 LSR
 TAY
 LDA PlayAreaColumnAddrs,Y
 STA $00
 LDA PlayAreaColumnAddrs+1,Y
 STA $01
 LDA M_Y,X
 CLC
 ADC #4
 SEC
 SBC #$40
 LSR
 LSR
 LSR
 TAY
 LDA ($00),Y
 LDY CurLevel
 BNE @Dungeon
 ; Same native walkability simplification as GetCollidableTile.
 LDY #8
@Walkable:
 CMP MarioWalkableTiles,Y
 BEQ @Clear
 DEY
 BPL @Walkable
 CMP #$89
 RTS
@Dungeon:
 CMP #$F0
 RTS
@Clear:
 CLC
 RTS
MarioWalkableTiles:
 .BYTE $8D,$91,$9C,$AC,$AD,$CC,$D2,$D5,$DF
MarioBounceSpeed:
 .BYTE 48,43,38,33,28,23,18,13,8,8,8,8,12,17,22,27,32,37,42,47

MarioFireRender:
 LDA IsUpdatingMode
 BEQ @Exit
 LDA MenuState
 ORA Paused
 BNE @Exit
 LDA GameMode
 CMP #5
 BEQ @Draw
 CMP #9
 BEQ @Draw
 CMP #$B
 BEQ @Draw
 CMP #$C
 BNE @Exit
@Draw:
 LDX #1
@Loop:
 LDA M_TTL,X
 BEQ @Next
 LDY #$60
@Find:
 LDA Sprites,Y
 CMP #$F8
 BEQ @Write
 TYA
 CLC
 ADC #4
 TAY
 BNE @Find
 BEQ @Next
@Write:
 LDA M_Y,X
 STA Sprites,Y
 LDA M_X,X
 STA Sprites+3,Y
 LDA M_PHASE,X
 AND #2
 ORA #$58
 STA Sprites+1,Y
 LDA #0
 STA Sprites+2,Y
@Next:
 DEX
 BPL @Loop
@Exit:
 RTS

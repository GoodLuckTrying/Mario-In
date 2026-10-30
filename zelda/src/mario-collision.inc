; Runs only where the native monster enables weapon collision, after its
; invulnerability checks. Borrow the room-item coordinates temporarily for
; the native damage/shove routines, then restore all three bytes exactly.
MarioFireCollision:
 LDA M_TTL
 ORA M_TTL+1
 BEQ @Exit
 LDA ObjX+19
 PHA
 LDA ObjY+19
 PHA
 LDA ObjDir+19
 PHA
 LDA #1
 STA M_COLL
@Loop:
 LDY M_COLL
 LDA M_TTL,Y
 BEQ @Next
 LDA M_DIR,Y
 STA ObjDir+19
 LDA M_X,Y
 SEC
 SBC #4
 STA ObjX+19
 CLC
 ADC #8
 STA $04
 LDA M_Y,Y
 SEC
 SBC #4
 STA ObjY+19
 CLC
 ADC #8
 STA $05
 LDA #$13
 STA $00
 LDA #$10
 STA $07
 LDA #$20
 STA $09
 LDA #10
 JSR DoObjectsCollide
 BEQ @Next
 JSR HandleMonsterWeaponCollision
 JSR BeginShove
 LDY M_COLL
 LDA #0
 STA M_TTL,Y
 JMP @Done
@Next:
 DEC M_COLL
 BPL @Loop
@Done:
 PLA
 STA ObjDir+19
 PLA
 STA ObjY+19
 PLA
 STA ObjX+19
 JMP GetObjectMiddle
@Exit:
 RTS
.ASSERT * <= $7FC0, lderror, "Mario collision code overlaps private state"

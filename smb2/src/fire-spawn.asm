MarioFireSpawn:
 LDA PlayerState
 ORA PlayerLock
 ORA PlayerInRocket
 ORA HoldingItem
 ORA PlayerDucking
 ORA PlayerCurrentSize
 BNE MarioFireSpawn_Exit
 BIT Player1JoypadPress
 BVC MarioFireSpawn_Exit
 LDA PlayerHealth
 CMP #$10
 BCC MarioFireSpawn_Exit
 LDY #8
 LDX #0
MarioFireSpawn_Count:
 LDA EnemyState,Y
 BNE MarioFireSpawn_CountActive
 STA M_FIRE,Y
MarioFireSpawn_CountActive:
 LDA M_FIRE,Y
 BEQ MarioFireSpawn_Next
 INX
MarioFireSpawn_Next:
 DEY
 BPL MarioFireSpawn_Count
 CPX #2
 BCS MarioFireSpawn_Exit
 LDX #8
MarioFireSpawn_Free:
 LDA EnemyState,X
 BEQ MarioFireSpawn_Create
 DEX
 BPL MarioFireSpawn_Free
MarioFireSpawn_Exit:
 RTS
MarioFireSpawn_Create:
 STX byte_RAM_12
 LDA #Enemy_VegetableSmall
 STA ObjectType,X
 JSR EnemyInit_Basic
 JSR UnlinkEnemyFromRawData
 LDA #1
 STA EnemyState,X
 STA ObjectProjectileTimer,X
 LDA #96
 STA M_FIRE,X
 LDA #0
 STA ObjectXSubpixel,X
 STA ObjectYSubpixel,X
 STA ObjectYVelocity,X
 STA ObjectAttributes,X
 STA EnemyArray_46E,X
 ; The rendered shot is eight pixels tall. The vegetable's native box
 ; samples below that image and makes it bounce visibly above the floor.
 LDA #$11
 STA EnemyArray_492,X
 LDA PlayerDirection
 TAY
 LDA MarioFireSpeed,Y
 STA ObjectXVelocity,X
 LDA PlayerXLo
 CLC
 ADC MarioFireOffset,Y
 STA ObjectXLo,X
 LDA MarioFirePage,Y
 ADC PlayerXHi
 STA ObjectXHi,X
 LDA PlayerYLo
 CLC
 ADC #12
 STA ObjectYLo,X
 LDA PlayerYHi
 ADC #0
 STA ObjectYHi,X
 LDA #5
 STA M_FIRE_SOUND
 LDA #6
 STA M_THROW
 RTS
MarioFireSpeed:
 .db $D0,$30
MarioFireOffset:
 .db $F8,16
MarioFirePage:
 .db $FF,0

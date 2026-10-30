MarioFireBehavior:
 DEC M_FIRE,X
 BEQ MarioFireDestroy
 JSR ApplyObjectPhysicsX
 JSR ApplyObjectPhysicsY
 JSR MarioFireCheckBounds
 BNE MarioFireDestroy
 LDA ObjectYVelocity,X
 CMP #$30
 BPL MarioFireGravityDone
 CLC
 ADC #5
 STA ObjectYVelocity,X
MarioFireGravityDone:
 JSR ObjectTileCollision
 LDA EnemyCollision,X
 AND #CollisionFlags_Left | CollisionFlags_Right | CollisionFlags_Up
 BNE MarioFireDestroy
 LDA EnemyCollision,X
 AND #CollisionFlags_Down
 BEQ MarioFireMove
 ; Resolve the eight-pixel image exactly against the tile surface.
 LDA ObjectYLo,X
 CLC
 ADC #8
 STA M_TEMP
 LDA ObjectYHi,X
 ADC #0
 STA ObjectYHi,X
 LDA M_TEMP
 AND #$F0
 SEC
 SBC #8
 STA ObjectYLo,X
 LDA ObjectYHi,X
 SBC #0
 STA ObjectYHi,X
 LDA #0
 STA ObjectYSubpixel,X
 LDA #$D0
 STA ObjectYVelocity,X
MarioFireMove:
 JSR HandleEnemyScreenBounds
 LDA EnemyState,X
 BEQ MarioFireDestroy
 JSR CheckObjectCollision
 LDA EnemyState,X
 BEQ MarioFireDestroy
 JMP MarioFireRender
MarioFireDestroy:
 LDA #0
 STA EnemyState,X
 STA M_FIRE,X
 RTS

MarioHurtKnockback:
 STA PlayerYVelocity
 LDA PlayerScreenX
 CMP SpriteTempScreenX
 BCC MarioHurtKnockback_Left
 LDA PlayerXVelocity
 CMP #$18
 BCC MarioHurtKnockback_Store
 LDA #$18
 BNE MarioHurtKnockback_Store
MarioHurtKnockback_Left:
 LDA PlayerXVelocity
 CMP #$E8
 BCS MarioHurtKnockback_Store
 LDA #$E8
MarioHurtKnockback_Store:
 STA PlayerXVelocity
 LDA #1
 STA PlayerInAir
 LDA #0
 STA M_SMB_X_FORCE
 RTS
MarioFireRender:
 JSR SetSpriteTempScreenPosition
 JSR FindSpriteSlot
 LDA SpriteTempScreenY
 CMP #$E8
 BCS MarioFireRender_Exit
 STA SpriteDMAArea,Y
 LDA SpriteTempScreenX
 STA SpriteDMAArea+3,Y
 LDA byte_RAM_10
 LSR A
 LSR A
 AND #2
 ORA #8
 STA SpriteDMAArea+1,Y
 LDA byte_RAM_10
 ASL A
 ASL A
 ASL A
 ASL A
 ASL A
 AND #$40
 STA SpriteDMAArea+2,Y
MarioFireRender_Exit:
 LDX byte_RAM_12
 RTS

; Return Z only when the shot belongs on this screen. Compare the full
; world position against the camera: crossing a world-page boundary within
; a scrolling viewport is valid, but wrapping the screen coordinate is not.
; Native vertical rooms wrap horizontally and keep their X page at zero.
MarioFireCheckBounds:
 LDA IsHorizontalLevel
 BEQ MarioFireCheckBounds_Wrap
 LDA ObjectXLo,X
 CMP ScreenBoundaryLeftLo
 LDA ObjectXHi,X
 SBC ScreenBoundaryLeftHi
 BNE MarioFireCheckBounds_Exit
 JMP MarioFireCheckBounds_Y
MarioFireCheckBounds_Wrap:
 LDA #0
 STA ObjectXHi,X
MarioFireCheckBounds_Y:
 ; Every room has a non-wrapping vertical viewport, including rooms
 ; whose world/camera coordinates cross a 256-pixel vertical page.
 LDA ObjectYLo,X
 CMP ScreenYLo
 LDA ObjectYHi,X
 SBC ScreenYHi
 BNE MarioFireCheckBounds_Exit
 LDA ObjectYLo,X
 SEC
 SBC ScreenYLo
 CMP #$E8
 BCS MarioFireCheckBounds_Exit
 LDA #0
MarioFireCheckBounds_Exit:
 RTS

MarioFireHit:
 ; The standard thrown-vegetable dispatcher handles enemy health,
 ; boss vulnerability/cooldowns and native boss-clear transitions.
 JSR EnemyCollisionBehavior_ProjectileItem
 LDY byte_RAM_12
 LDA #0
 STA M_FIRE,Y
 STA EnemyState,Y
 LDX byte_RAM_ED
 RTS

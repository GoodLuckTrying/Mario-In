; A brief SMB1-style fireball chirp on SMB2's SFX pulse channel.
; Native queued effects take priority; music resumes after five frames.
MarioFireSound:
 LDA M_FIRE_SOUND
 CMP #5
 BNE MarioFireSound_Tick
 LDA #SoundEffect1_ThrowItem
 STA SoundEffectPlaying1
 LDA #$9A
 STA SQ2_VOL
 LDA #$99
 STA SQ2_SWEEP
 LDA #$3A
 STA SQ2_LO
 LDA #$0A
 STA SQ2_HI
MarioFireSound_Tick:
 DEC M_FIRE_SOUND
 BNE MarioFireSound_Exit
 LDA #0
 STA SoundEffectPlaying1
 LDA #$90
 STA SQ2_VOL
 LDA #$7F
 STA SQ2_SWEEP
MarioFireSound_Exit:
 RTS

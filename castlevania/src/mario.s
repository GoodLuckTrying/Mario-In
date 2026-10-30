.setcpu "6502"
.macpack longbranch
.include "memory.inc"
.export MarioUpdate, JumpStart, VerticalMove, AirDirection, SelectPlayerSprite
.export Interactions, FarInteractions
.export ResetMario
.export SetNativeSpeed
.export AfterMarioUpdate
.export RightLocalBound, LeftLocalBound
.export MarioDamage, GetPlayerCollisionY, CollisionSetup, ActorEnd, SubweaponAction, MoveCentered, RightScrollBoundary, DoorUpdate, LandingReset, SideOffset
.export FireballWalls, FireballBrickCollision
.export FastSpriteSetup, NextOamIndex
.export SpriteBudgetNext
.export TileAtPoint, TileAtPointReturn
.export MapperReset, FarRefreshChr, PrepareNativeChr, CustomSpriteChr
.export ScrollSpawnBridge, PlatformCheck, PlatformContact
.export PostNativeAi, ConvertWhipDrops, GameplayDamage
.export PrepareActorBank, FarScriptedAi
.export DeferredSideCheck, DeferredFootCheck
.export HudIrq, MainLoopIrq, FinishHudSetup

.segment "BRIDGES"
; MMC5 starts with only the last 8KB PRG bank mapped. Establish the native
; fixed 16KB bank before entering the original reset routine at C008.
MapperReset:
    lda #1
    sta $5100
    ldy #5
    jsr $C1D6
    jmp InitializeMapper
FarRefreshChr:
    ldy #5
    jsr $C1D6
    jmp RefreshSpriteChr

.segment "SCROLLBRIDGE"
; Reuse the original scroll/spawn wrapper. Stage metatiles live in bank 4;
; object placement uses fixed-bank records and can run in the custom bank 5.
ScrollSpawnBridge:
    ldy #5
    jsr $C1D6
    jsr SpawnScrolledObjects
    ldy #4
    jsr $C1D6
    lda $3C
    cmp #1
    beq @draw
    cmp #2
    beq @draw
    rts
@draw:
    jmp $F605

.segment "BANK5"
SpawnScrolledObjects:
    lda $3C
    cmp #1
    beq @mode
    cmp #2
    bne @done
@mode:
    lda $18
    cmp #8
    beq @done
    cmp #$0C
    beq @done
    jsr $D132
    lda $6D
    cmp $76
    beq @done
    jsr $D196                 ; original records, persistence and slot assignment
    ; Native spawning assumes the camera low byte is a multiple of 64.
    ; Correct the skipped boundary and precompensate the AI's camera shift,
    ; so the new candle and enemy spawner keep their authored world position.
    ldy #0
    lda $49
    bpl @delta
    dey
@delta:
    sta M_SPAWN_OFFSET
    lda $2E
    and #$3F
    clc
    adc M_SPAWN_OFFSET
    sta M_SPAWN_OFFSET
    tya
    adc #0
    sta M_SPAWN_OFFSET_HI
    lda $6D
@slot:
    cmp #6
    bcc @adjust
    sbc #6
    bcs @slot
@adjust:
    tax
    lda $0166,x
    beq @candle               ; no enemy record: preserve its native hidden flag
    lda $0172,x
    sec
    sbc M_SPAWN_OFFSET
    sta $0172,x
    lda $0160,x
    sbc M_SPAWN_OFFSET_HI
    and #1
    sta $0160,x
@candle:
    txa
    clc
    adc #14
    tax
    lda $0434,x
    beq @empty                ; native empty/persistent record did not spawn
    lda $038C,x
    sec
    sbc M_SPAWN_OFFSET
    sta $038C,x
    lda $0300,x
    sbc M_SPAWN_OFFSET_HI
    and #1
    sta $0300,x
@done:
    rts
@empty:
    ; D285 hides an unused slot but leaves its old pose. Never convert that
    ; hidden flag into a page coordinate or retain the previous pickup.
    lda #0
    sta $031C,x
    sta M_DROP_KIND,x
    sta M_DROP_TIMER,x
    rts

InitializeMapper:
    lda #0
    sta M_SPLIT_ARMED
    sta $5101                 ; independent 8KB sprite/background CHR banks
    sta $5104
    sta $5113
    sta $5127                 ; native graphics transfers write original bank
    sta $512B                 ; original background graphics stay in bank zero
    sta $5200
    sta $5204
    lda #2
    sta $5102                 ; enable the original 8KB cartridge work RAM
    lda #1
    sta $5103
    lda #$44
    sta $5105                 ; original vertical nametable mirroring
    ldx #24
@palette:
    lda $CDE9,x               ; preserve the entire native sprite palette command
    sta M_NATIVE_PALETTE,x
    dex
    bpl @palette
    jmp $C008

; Graphics loads run with rendering/NMI disabled. Copy the complete original
; bank to a separate sprite bank, relocate every displaced native sprite tile,
; then install Mario. Background pixels never share these reserved slots.
RefreshSpriteChr:
    lda #0
    sta $00
    sta $01
    sta $02
    sta $03
    sta $6220
@copyOriginal:
    jsr CopyChrPair
    jsr AdvanceChrSource
    lda $00
    sta $02
    lda $01
    sta $03
    inc $6220
    bne @copyOriginal          ; all 256 pairs, including stage and boss art
    lda #0
    sta $00
    sta $01
@relocate:
    lda $6220
    asl
    tay
    lda NativeChrDest,y
    sta $02
    lda NativeChrDest+1,y
    sta $03
    jsr CopyChrPair
    jsr AdvanceChrSource
    inc $6220
    lda $6220
    cmp #61
    bne @relocate
    lda #1
    sta $5127
    bit $2002
    lda #0
    sta $2006
    sta $2006
    lda #<CustomSpriteChr
    sta $00
    lda #>CustomSpriteChr
    sta $01
    lda #<$07A0
    sta $02
    lda #>$07A0
    sta $03
    ldy #0
@custom:
    lda ($00),y
    sta $2007
    inc $00
    bne @count
    inc $01
@count:
    lda $02
    bne @low
    dec $03
@low:
    dec $02
    lda $02
    ora $03
    bne @custom
    jmp $C1D4                 ; displaced native return to bank 6

AdvanceChrSource:
    clc
    lda $00
    adc #32
    sta $00
    bcc @done
    inc $01
@done:
    rts

CopyChrPair:
    lda #0
    sta $5127
    bit $2002
    lda $01
    sta $2006
    lda $00
    sta $2006
    lda $2007                 ; discard the PPU's buffered read
    ldx #0
@read:
    lda $2007
    sta $6200,x
    inx
    cpx #32
    bne @read
    lda #1
    sta $5127
    bit $2002
    lda $03
    sta $2006
    lda $02
    sta $2006
    ldx #0
@write:
    lda $6200,x
    sta $2007
    inx
    cpx #32
    bne @write
    rts

NativeChrDest: .incbin "build/native-chr-dest.bin"
CustomSpriteChr: .incbin "build/custom-sprites.chr"

.segment "BANK6"
; All ten native graphics callers execute in bank 6. Select the original
; graphics bank for their unmodified PPU transfers, preserving the command.
PrepareNativeChr:
    pha
    lda #0
    sta $5127
    pla
    jmp $FD23

; The native wall handler runs before movement, in a different bank from
; fireballs. Consume the preceding frame's solid-terrain contacts here. Its
; authored wall table, debris, background edits, persistence and drops remain
; native. A pending contact survives a fireball disappearing into a wall.
FireballWalls:
    ldx #0
@loop:
    stx M_PROJECTILE
    lda M_FB_BRICK_PENDING,x
    beq @next
    lda #0
    sta M_FB_BRICK_PENDING,x
    lda $28
    cmp M_LAST_STAGE
    bne @next
    jsr $A837                 ; native breakable-wall table traversal
@next:
    ldx M_PROJECTILE
    inx
    cpx #2
    bne @loop
    lda M_WHIP_BRICK_PENDING
    beq @done
    lda #0
    sta M_WHIP_BRICK_PENDING
    lda $28
    cmp M_LAST_STAGE
    bne @done
    lda #2
    sta M_PROJECTILE
    jmp $A837                 ; same native wall path for a whip contact
@done:
    rts

FireballBrickCollision:
    ldx M_PROJECTILE
    cpx #2
    beq @whip
    lda M_FB_BRICK_PAGE,x
    sta $03
    lda M_FB_BRICK_Y,x
    tay
    lda M_FB_BRICK_X,x
    tax
    lda #4                    ; 8x8 fireball against the native 16x16 wall
    sta $11
    sta $13
@overlap:
    jsr $A048                 ; native world-coordinate rectangle overlap
    bcs @done
    ldx M_PROJECTILE
    cpx #2
    beq @count
    lda #0
    sta M_FB_ACTIVE,x
    lda #$F4
    sta $0355,x
@count:
    inc M_BRICK_COUNTER
    clc
@done:
    rts
@whip:
    lda M_WHIP_BRICK_PAGE
    sta $03
    ldy M_WHIP_BRICK_Y
    ldx M_WHIP_BRICK_X
    lda M_WHIP_HALF
    sta $13
    lda #4
    sta $11
    jmp @overlap

MarioUpdate:
    lda $F7
    sta M_HELD
    lda M_MAGIC
    cmp #$4D
    beq @initialized
    jsr InitializeMario
@initialized:
    lda $47
    beq @normal
    jmp $9350                 ; original power-up / stun animation
@normal:
    lda $28
    cmp M_LAST_STAGE
    beq @sameStage
    lda #0
    sta M_SMB_X_SPEED
    sta M_SMB_X_FORCE
    sta M_SMB_X_ABS
    sta M_VX_HI
    sta M_VX_LO
    sta M_VY_HI
    sta M_VY_LO
    sta M_Y_FRAC
@sameStage:
    lda #0
    sta M_PLATFORM_SLOT
    sta M_PLATFORM_VX_LO
    sta M_PLATFORM_VX_HI
    lda $3F
    sta M_PREV_Y
    jsr FarUpdateVelocity
    jsr SetNativeSpeed
    jmp $9363                 ; preserve native transition stack unwinding

AfterMarioUpdate:
    lda $18
    cmp #5
    beq :+
    jmp @switchBank
:
    lda $046C
    cmp #2
    bcs @faceCheck
    lda $28                   ; only these native stages contain platforms
    cmp #4
    beq @platformSupport
    cmp #5
    beq @platformSupport
    cmp #$0A
    bne @terrain
@platformSupport:
    jsr $AC70                 ; dynamic platforms are also genuine support
@terrain:
    jsr FarTerrainCollision   ; SMB feet/sides resolve after X and Y movement
@faceCheck:
    lda $046C
    beq @face
    cmp #1
    bne @buttons
@face:
    lda M_FACING
    lsr
    sta $0450
@buttons:
    ; A bounded pan can move the camera and Mario locally in the same frame.
    ; Native object AI still needs to consume that camera delta exactly once.
    lda $49
    beq @scrollReady
    lda $3C
    and #$FB
    sta $3C
@scrollReady:
    jsr $F60F                 ; sync PPU scroll even when movement/scrolling stops
    lda M_HELD
    sta M_PREV_HELD
    sta $F7
@switchBank:
    ldy #4
    jmp $C1D6                 ; displaced caller bank switch, returns in bank 4

InitializeMario:
    lda #0
    ldx #0
@clear:
    sta $6000,x
    sta $6100,x
    inx
    bne @clear
    lda #$FF
    sta M_PALETTE
    ldx #$0F
@soundSentinel:
    sta $7FF0,x
    dex
    bpl @soundSentinel
    lda #1
    sta M_FACING
    sta M_MOVING_DIR
    sta M_AREA_TYPE
    lda #3
    sta M_COLL_DIR
    lda #8
    sta M_ENGINE_MODE
    lda #$70
    sta M_FALL_FORCE
    lda #2
    sta $70
    lda #$4D
    sta M_MAGIC
    lda #$40
    sta M_PREV_HEALTH
    rts

FarUpdateVelocity:
    lda #>(UpdateVelocity-1)
    pha
    lda #<(UpdateVelocity-1)
    pha
    ldy #5
    jmp $C1D6                 ; fixed-bank RTS enters bank 5 after switching

FarTerrainCollision:
    lda #>(TerrainCollision-1)
    pha
    lda #<(TerrainCollision-1)
    pha
    ldy #5
    jmp $C1D6

.segment "BANK5"
PlatformVelocity:
    lda $046C
    bne @carry
    lda M_PHYS_STATE
    cmp #1
    bne @carry
    ; A fresh ground A edge already selected SMB's jumping state. Keep the
    ; native support result for the jump dispatcher, but detach its X carry.
    lda #0
    sta M_PLATFORM_SLOT
    sta M_PLATFORM_VX_LO
    sta M_PLATFORM_VX_HI
    jmp @ownSpeed
@carry:
    ldx M_PLATFORM_SLOT
    ; Native platform X speed is a signed fraction, scaled by 2^(scale+1).
    lda $03FC,x
    sta M_PLATFORM_VX_LO
    ldy #0
    cmp #$80
    bcc @sign
    dey
@sign:
    sty M_PLATFORM_VX_HI
    lda $0488,x
    tax
@scale:
    asl M_PLATFORM_VX_LO
    rol M_PLATFORM_VX_HI
    dex
    bpl @scale
@ownSpeed:
    lda M_VX_LO
    clc
    adc M_PLATFORM_VX_LO
    sta $3D
    lda M_VX_HI
    adc M_PLATFORM_VX_HI
    sta $3E
    ora $3D
    beq @stationary
    lda #1
    ldy $3E
    bpl @direction
    lda $3D
    eor #$FF
    clc
    adc #1
    sta $3D
    lda $3E
    eor #$FF
    adc #0
    sta $3E
    lda #2
@direction:
    sta $10
    jmp $C1D4
@stationary:
    lda #0
    sta $10
    jmp $C1D4

UpdateVelocity:
    jsr UpdateCrouch
    jsr UpdateBodySize
    lda M_ANIM_TIMER
    beq @animReady
    dec M_ANIM_TIMER
@animReady:
    lda $046C
    beq @ground
    cmp #1
    beq @air
    cmp #7
    beq @fall
    lda #0
    sta M_VX_LO
    sta M_VX_HI
    sta M_SMB_X_SPEED
    sta M_SMB_X_FORCE
    jmp $C1D4
@fall:
    lda #1
    sta $046C
    sta $0514
    lda #0
    sta M_VY_LO
    sta M_VY_HI
    lda M_FALL_FORCE
    sta M_GRAVITY
    lda #2
    sta M_PHYS_STATE
@air:
    lda M_PHYS_STATE
    bne @state
    lda #2
    ldy M_VY_HI
    bpl @state
    lda #1
    bne @state
@ground:
    lda #0
    sta M_VY_LO
    sta M_VY_HI
    lda M_HELD
    and #$80
    beq @state
    lda M_PREV_HELD
    and #$80
    bne @groundState
    lda #1                     ; SMB switches to air physics before takeoff
    bne @state
@groundState:
    lda #0
@state:
    sta M_PHYS_STATE
    lda M_SMB_X_ABS
    sta M_TAKEOFF_ABS
    lda M_HELD
    and #3
    sta M_INPUT_DIR
    lda $046C
    bne @inputReady
    lda M_HELD
    and #4
    beq @inputReady
    lda #0                    ; SMB Down on ground removes horizontal input
    sta M_INPUT_DIR            ; momentum still decays through normal friction
@inputReady:
    lda M_RUNNING_TIMER
    beq @timerDone
    dec M_RUNNING_TIMER
@timerDone:
    jsr X_Physics
    lda M_PHYS_STATE
    bne @airFriction
    jsr GetPlayerAnimSpeed
    lda M_INPUT_DIR
    beq @friction
    sta M_FACING
    bne @friction
@airFriction:
    lda M_INPUT_DIR
    beq @convert
@friction:
    jsr ImposeFriction
@convert:
    lda M_SMB_X_SPEED
    asl
    asl
    asl
    asl
    sta M_VX_LO
    lda M_SMB_X_SPEED
    lsr
    lsr
    lsr
    lsr
    cmp #8
    bcc @positive
    ora #$F0
@positive:
    sta M_VX_HI
    lda #0
    ldy M_SMB_X_SPEED
    beq @direction
    lda #1
    tya
    bpl @right
    lda #2
    bne @moving
@right:
    lda #1
@moving:
    sta M_MOVING_DIR
@direction:
    sta M_DIRECTION
    sta $0584
    sta $10
    lda M_HELD
    and #$FC
    ora M_DIRECTION
    sta $F7
    jmp $C1D4

; Keep the body anchor fixed while crouching. Simon's action 3 moves Y by
; four pixels and locks jumping; Mario uses the normal ground/air dispatcher.
UpdateCrouch:
    lda $18
    cmp #5
    bne @clear
    lda $046C
    cmp #3
    bne @normalAction
    lda $3F                   ; normalize an old native crouch/save-state pose
    sec
    sbc #4
    sta $3F
    sta $0354
    lda #0
    sta $046C
@normalAction:
    lda M_POWER
    beq @clear
    lda $046C
    beq @groundInput
    cmp #1
    beq @done                 ; original SMB retains crouch during its jump
    bne @clear
@groundInput:
    lda M_HELD
    and #3
    bne @clear                ; original SMB Down+direction input filter
    lda M_HELD
    and #4
    bne @store
@clear:
    lda #0
@store:
    sta M_CROUCH
@done:
    rts

UpdateBodySize:
    lda M_CROUCH
    bne @short
    lda M_POWER
    bne @save
@short:
    lda #0
@save:
    sta M_BODY_TALL
    lda #6
    ldx M_POWER
    bne @radius
    lda #5
@radius:
    sta M_HURT_RADIUS_X
    rts

.include "smb-land.inc"
.include "smb-collision.inc"

.segment "BANK6"
; Native prediction and landing remain available to scripted stairs/damage.
; Normal Mario terrain contact is resolved once, after movement, like SMB.
DeferredSideCheck:
    lda $18
    cmp #5
    bne @native
    lda $046C
    cmp #2
    bcs @native
    clc
    rts
@native:
    lda $046C
    jmp $9ED1

DeferredFootCheck:
    lda $18
    cmp #5
    bne @native
    lda $046C
    cmp #1
    beq @air
    cmp #0
    bne @native
    ; Grounded SMB moves first and discovers lost support afterwards. Native
    ; pre-move support would dispatch Simon's walk-off state one update early.
    sec
    rts
@air:
    clc
    rts
@native:
    lda $3F
    sec
    jmp $9E73

SideOffset:
    lda M_BODY_TALL
    bne @big
    lda SmallSideOffsets,y
    bne @save
@big:
    lda BigSideOffsets,y
@save:
    sta $4B
    rts
; SMB sides probe raw Y+24 for small Mario and raw Y+8/+24 for big.
; Castlevania's five iterations reuse those two heights, not Simon's body.
SmallSideOffsets: .byte 8,8,8,8,8
BigSideOffsets: .byte 8,8,8,$F8,$F8

LandingReset:
    jsr $9AF8
    lda #0
    sta M_VY_HI
    sta M_VY_LO
    sta M_PHYS_STATE
    rts

RightLocalBound:
    bcs @stop                 ; coordinate overflow
    cmp #$F0
    bcs @stop
    jmp $98CF
@stop:
    jmp $990A

LeftLocalBound:
    bcc @stop                 ; coordinate underflow
    cmp #8
    bcc @stop
    jmp $98ED
@stop:
    lda #8
    jmp $98ED                 ; SMB's left edge is sprite-left X=0

DoorUpdate:
    lda #0
    sta $3D
    lda #1
    sta $3E
    jsr $FA6A
    rts
RightScrollBoundary:
    ; The native caller has already reached the maximum camera page. Every
    ; low-byte result on that page reaches/passes its zero-byte door lock.
    jmp $9893
MoveCentered:
    lda M_MAGIC
    cmp #$4D
    bne @nativeSpeed
    lda $18
    cmp #5
    bne @nativeSpeed
    lda $046C
    beq @smbSpeed
    cmp #1
    bne @nativeSpeed
@smbSpeed:
    ; Add platform carry separately; SMB acceleration/friction keep their own
    ; velocity. Use the same signed accumulator and camera limits for both.
    lda M_VX_LO
    clc
    adc M_PLATFORM_VX_LO
    sta M_MOVE_LO
    lda M_VX_HI
    adc M_PLATFORM_VX_HI
    sta M_MOVE_HI
    lda $03A8
    clc
    adc M_MOVE_LO
    sta $03A8
    lda M_MOVE_HI
    adc #0
    bpl @integerStep
    eor #$FF
    clc
    adc #1
@integerStep:
    sta $3E
    lda #0
    sta $3D
@nativeSpeed:
    lda $48                   ; active boss/room locks forbid all camera pans
    beq @unlocked
    lda $3C
    ora #4
    sta $3C
@unlocked:
    lda $038C
    sta $605D
    cmp #$80
    beq @centered
    ; SMB wall ejection can leave Mario one pixel off the scroll center.
    ; Consume that local offset before panning; a zero-pixel fractional step
    ; must never recompute his world X from the center instead of his body.
    lda $3C
    ora #4
    sta $3C
@centered:
    lda $3C
    and #4
    bne @localMove
    lda $3C
    and #3
    cmp #1
    beq @directRight
    cmp #2
    bne @localMove
    jsr ScrollLeftBounded
    jmp $98F3
@directRight:
    jsr ScrollRightBounded
    jmp $98F3
@localMove:
    jsr $98AB
    lda $48
    bne @done
    lda $3C
    and #4
    beq @done
    lda $3C
    and #3
    cmp #1
    beq @right
    cmp #2
    bne @done
    lda $605D
    cmp #$80                  ; consume the last camera pixel before going local
    bcc @done
    lda $038C
    cmp #$81
    bcs @done
    bcc @center
@right:
    lda $605D
    cmp #$81                  ; native prediction can mark the center as local
    bcs @done
    lda $038C
    cmp #$80
    bcc @done
@center:
    lda $038C
    cmp #$80
    bcc @scrollLeft
    sec
    sbc #$80
    sta $3E
    lda #0
    sta $3D
    lda #$80
    sta $038C
    jsr ScrollRightBounded    ; retain overshoot without bypassing native locks
    jmp @centerX
@scrollLeft:
    lda #$80
    sec
    sbc $038C
    sta $3E
    lda #0
    sta $3D
    lda #$80
    sta $038C
    jsr ScrollLeftBounded
@centerX:
    jsr $98F3
@done:
    rts

ScrollRightBounded:
    lda $3E
    sta M_SCROLL_STEP
    jsr $D015                 ; original stage/vertical-room right boundary
    sta M_SCROLL_LIMIT
    ldx $28
    lda $FC5E,x               ; original boss trigger: room nibble / camera page
    lsr
    lsr
    lsr
    lsr
    cmp $46
    bne @distance
    lda $FC5E,x
    and #$0F
    cmp M_SCROLL_LIMIT
    bcs @distance
    sta M_SCROLL_LIMIT        ; land exactly on the native boss activation point
@distance:
    lda $2F
    cmp M_SCROLL_LIMIT
    bcs @zero
    lda M_SCROLL_LIMIT
    sec
    sbc $2F
    cmp #1
    bne @move
    lda $2E
    beq @move                 ; a full page is available
    eor #$FF
    clc
    adc #1
    cmp $3E
    bcs @move
    sta $3E
    bcc @move
@zero:
    lda #0
    sta $3E
@move:
    jsr $991F
    lda M_SCROLL_STEP
    sec
    sbc $3E
    beq @done
    clc
    adc $038C                 ; unused camera movement becomes local movement
    sta $038C
    lda $3C
    ora #4
    sta $3C
@done:
    rts

ScrollLeftBounded:
    lda $3E
    sta M_SCROLL_STEP
    jsr $D025                 ; native left sentinel is the page BEFORE the limit
    clc
    adc #1
    sta M_SCROLL_LIMIT
    lda $2F
    cmp M_SCROLL_LIMIT
    bcc @zero
    bne @move
    lda $2E
    cmp $3E
    bcs @move
    sta $3E
    bcc @move
@zero:
    lda #0
    sta $3E
@move:
    jsr $9944
    lda M_SCROLL_STEP
    sec
    sbc $3E
    beq @done
    sta M_SCROLL_STEP
    lda $038C
    sec
    sbc M_SCROLL_STEP
    sta $038C
    lda $3C
    ora #4
    sta $3C
@done:
    rts

SubweaponAction:
    lda $F7
    and #8
    beq @no
    lda $015B
    beq @no
    lda $0434
    bne @no
    jmp $9A2F
@no:
    clc
    rts

; Native Simon jumps far enough to leave a platform's landing rectangle at
; once. SMB's slower first upward step must explicitly detach while rising.
PlatformCheck:
    lda $046C
    cmp #1
    bne @native
    lda M_VY_HI
    bmi @ascending
@native:
    lda #$1A
    sta $4E
    jmp $AC74
@ascending:
    jmp $ACC4                 ; clear platform support and restore own speed

PlatformContact:
    lda $18
    cmp #5
    bne @native
    lda $046C
    cmp #2
    bcs @native               ; retain native stairs, crouch and scripted actions
    stx M_PLATFORM_SLOT
    ; Both routines live in switchable banks. Return through the fixed bank
    ; switch, then native AD4D restores carry before the original caller.
    lda #>($AD4D-1)
    pha
    lda #<($AD4D-1)
    pha
    lda #>(PlatformVelocity-1)
    pha
    lda #<(PlatformVelocity-1)
    pha
    ldy #5
    jmp $C1D6
@native:
    lda $0584
    jmp $AD03

AirDirection:
    lda M_DIRECTION
    sta $0584
    sta $10
    rts

SetNativeSpeed:
    lda $18
    cmp #5
    bne @original
    lda M_MAGIC
    cmp #$4D
    bne @original
    lda $046C
    beq @mario
    cmp #1
    beq @mario
    cmp #7
    beq @mario
@original:
    lda #0
    sta $3D
    lda #1
    sta $3E
    jmp $AD57
@mario:
    lda M_VX_HI
    bmi @negative
    sta $3E
    lda M_VX_LO
    sta $3D
    clc
    rts
@negative:
    lda M_VX_LO
    eor #$FF
    clc
    adc #1
    sta $3D
    lda M_VX_HI
    eor #$FF
    adc #0
    sta $3E
    clc
    rts

JumpStart:
    lda #0
    sta M_PLATFORM_SLOT
    sta M_PLATFORM_VX_LO
    sta M_PLATFORM_VX_HI
    lda $0142
    and #$FB
    sta $0142
    ldy #0
    lda M_TAKEOFF_ABS
    cmp #$09
    bcc @choose
    iny
    cmp #$10
    bcc @choose
    iny
    cmp #$19
    bcc @choose
    iny
    cmp #$1C
    bcc @choose
    iny
@choose:
    lda JumpForces,y
    sta M_JUMP_FORCE
    sta M_GRAVITY
    lda FallForces,y
    sta M_FALL_FORCE
    lda JumpSpeeds,y
    sta M_VY_HI
    lda #0
    sta M_VY_LO
    sta M_Y_FRAC
    lda $3F
    sta M_JUMP_ORIGIN
    jsr VerticalMove           ; SMB moves vertically on the takeoff frame
    sec
@blocked:
    rts

JumpForces: .byte $20,$20,$1E,$28,$28
FallForces: .byte $70,$70,$60,$90,$90
JumpSpeeds: .byte $FC,$FC,$FC,$FB,$FB

VerticalMove:
    lda $3F
    sta M_PREV_Y
    lda M_VY_HI
    bpl @falling
    lda M_HELD
    and M_PREV_HELD
    and #$80
    bne @integrate
    lda M_JUMP_ORIGIN
    sec
    sbc $3F
    cmp #1
    bcc @integrate
@falling:
    lda M_FALL_FORCE
    sta M_GRAVITY
@integrate:
    ; Original SMB order: integrate old velocity, then apply force.
    lda M_Y_FRAC
    clc
    adc M_VY_LO
    sta M_Y_FRAC
    lda $3F
    adc M_VY_HI
    sta $3F
    lda M_VY_HI
    bpl @applyForce
    lda $3F
    cmp M_PREV_Y
    bcc @applyForce
    beq @applyForce
    ; Castlevania's world Y is one byte. Stop at the top of its coordinate
    ; range rather than wrapping an upward jump into the native pit detector.
    lda #0
    sta $3F
    sta M_Y_FRAC
    sta M_VY_HI
    sta M_VY_LO
    lda M_FALL_FORCE
    sta M_GRAVITY
@applyForce:
    lda M_VY_LO
    clc
    adc M_GRAVITY
    sta M_VY_LO
    lda M_VY_HI
    adc #0
    sta M_VY_HI
    cmp #4
    bmi @contact
    lda M_VY_LO
    cmp #$80
    bcc @contact
    lda #4
    sta M_VY_HI
    lda #0
    sta M_VY_LO
@contact:
    lda M_VY_HI
    bmi @upward
    lda #1
    sta $0514
    clc
    rts
@upward:
    jsr HeadCollision
    bcs @free
    lda #1                    ; SMB bonks after movement and falls next frame
    sta M_VY_HI
    lda #1
    sta $0514
    clc
    rts
@free:
    lda #0
    sta $0514
    clc
    rts

HeadCollision:
    ; SMB uses one centered head probe, its raw-Y nibble and size cutoff.
    lda $3F
    ldx M_BODY_TALL
    beq @smallExtent
    cmp #48
    bcc @clear
    bcs @nibble
@smallExtent:
    cmp #32
    bcc @clear
@nibble:
    and #$0F
    sta M_HEAD
    lda $3F
    ldx M_BODY_TALL
    beq @small
    sec
    sbc #12
    jmp @point
@small:
    clc
    adc #2
@point:
    sta $10
    sta M_OLD_HEAD
    lda #0
    sta $11
    lda $41
    sta $13
    lda $40
    sta $12
    jsr $F9A0
    beq @clear
    lda M_HEAD
    cmp #4
    bcs @blocked
    ; SMB's skipped four-pixel band assumes 16-pixel blocks. Preserve that
    ; rule for thick terrain, but catch isolated 8-pixel Castlevania ceilings.
    lda M_OLD_HEAD
    sec
    sbc #8
    sta $10
    jsr $F9A0
    bne @clear
    lda M_OLD_HEAD
    clc
    adc #8
    sta $10
    jsr $F9A0
    beq @blocked
@clear:
    sec
    rts
@blocked:
    clc
    rts

.segment "BANK0"
SpriteBudgetNext:
    dec $07
    bpl @next
    ; The native shuffled OAM pool has 47 gameplay entries. Stop when it is
    ; full instead of decoding actors that can only overwrite earlier OAM.
    ; This also avoids hiding the first sprite when the pool is exactly full.
    pla
    pla                       ; return directly from the metasprite caller
    rts                       ; to UpdateSprites' caller in fixed ROM
@next:
    iny
    jmp $812E

FastSpriteSetup:
    cpx #3
    bcc @prepare              ; player and fireball slots have custom graphics
    lda $0434,x
    bne @prepare
    lda $031C,x
    beq @skip
    cpx #23
    bcs @prepare              ; native auxiliary sprites may have no AI
    lda $18
    cmp #5
    bne @prepare              ; preserve native scripted/title rendering
@skip:
    jmp $80A8                 ; inactive gameplay actors cannot draw old poses
@prepare:
    lda $0338,x
    sta $00
    jmp $8077                 ; resume native coordinate/facing preparation

SelectPlayerSprite:
    lda M_MAGIC
    cmp #$4D
    jne @original
    cpx #0
    jeq @player
    cpx #3
    bcs @item
    txa
    sec
    sbc #1
    tay
    lda $18
    cmp #5
    bne @blank
    lda M_FB_ACTIVE,y
    beq @blank
    lda $1A
    and #4
    beq @fire1
    lda #<FireSprite2
    ldy #>FireSprite2
    bne @pointer
@fire1:
    lda #<FireSprite1
    ldy #>FireSprite1
    bne @pointer
@item:
    lda $18
    cmp #5
    jne @original
@drop:
    lda M_DROP_KIND,x
    beq @original
    cmp #4
    bcs @blank
    asl
    tay
    lda ItemSprites-2,y
    sta $08
    lda ItemSprites-1,y
    sta $09
    lda #0
    sta $00
    sta $4B
    jmp $80A5
@blank:
    jmp $80A8                 ; zero-sprite metasprites consume no OAM entries
@pointer:
    sta $08
    sty $09
    lda #0
    sta $00
    sta $4B
    jmp $80A5
@original:
    lda $031C,x
    beq @skip                 ; native pose zero is the empty metasprite
    asl
    bcs @highOriginal
    jmp $808C
@highOriginal:
    jmp $809A
@skip:
    jmp $80A8
@player:
    lda M_MAGIC
    cmp #$4D
    beq @choose
    lda $031C
    asl
    bcs @highOriginal
    jmp $808C
@choose:
    lda M_INVINCIBLE
    ora $5B
    beq @visible
    lda $1A
    and #4
    bne @blank
@visible:
    lda $038C
    cmp M_RENDER_X
    bne @moving
    lda $0354
    cmp M_RENDER_Y
    bne @moving
    lda M_RENDER_MOVING
    beq @tracked
    dec M_RENDER_MOVING
    jmp @tracked
@moving:
    lda #4
    sta M_RENDER_MOVING
@tracked:
    lda $038C
    sta M_RENDER_X
    lda $0354
    sta M_RENDER_Y
    lda $046C
    cmp #8
    bne @alive
    ldy #12
    jmp @sprite
@alive:
    lda M_CROUCH
    beq @standing
    lda M_POWER
    beq @standing
    ldy #13                   ; original SMB crouching art for grown Mario
    jmp @sprite
@standing:
    ldy #3                    ; standing
    lda $046C
    cmp #1
    beq @jump
    cmp #7
    beq @jump
    lda $18
    cmp #5
    bne @scriptedWalk
    lda $046C
    bne @scriptedWalk
    lda M_SMB_X_ABS
    cmp #9
    bcc @walk
    lda M_MOVING_DIR
    and M_FACING
    beq @skid
@walk:
    lda M_SMB_X_SPEED
    ora M_INPUT_DIR
    bne @walkFrame
    lda #0
    sta M_ANIM_FRAME
    beq @size
@walkFrame:
    ldy M_ANIM_FRAME
    lda M_ANIM_TIMER
    bne @size
    lda M_ANIM_SET
    sta M_ANIM_TIMER
    lda M_ANIM_FRAME
    clc
    adc #1
    cmp #3
    bcc @nextFrame
    lda #0
@nextFrame:
    sta M_ANIM_FRAME
    jmp @size
@skid:
    lda #0
    sta M_ANIM_FRAME
    ldy #10
    lda M_POWER
    beq @sprite
    iny
    bne @sprite
@scriptedWalk:
    lda M_VX_LO
    ora M_VX_HI
    ora M_RENDER_MOVING
    beq @size
    lda $1A
    lsr
    lsr
    lsr
    and #3
    tay
    cpy #3
    bne @size
    ldy #1
    bne @size
@jump:
    lda M_PHYS_STATE
    cmp #2
    bne @jumpPose
    ldy M_ANIM_FRAME           ; SMB keeps its current walk frame on a walk-off
    jmp @size
@jumpPose:
    ldy #4
@size:
    lda M_POWER
    beq @small
    tya
    clc
    adc #5
    tay
@small:
@sprite:
    tya
    asl
    tay
    lda MarioSprites,y
    sta $08
    lda MarioSprites+1,y
    sta $09
    lda #0
    sta $00
    jsr AttachWhip
    jmp $80A5

AttachWhip:
    lda $18
    cmp #5
    beq @gameplay
    lda #0
    sta M_WHIP_TIMER
    sta M_WHIP_BRICK_PENDING
@done:
    rts
@gameplay:
    lda M_WHIP_TIMER
    beq @done
    ldx #0
    lda M_POWER
    beq @phase
    ldx #4
@phase:
    lda M_WHIP_TIMER
    cmp #17
    bcs @table
    inx
    inx
@table:
    cpx M_WHIP_SPRITE_PHASE
    bne @compose
    lda M_WHIP_LOWER
    cmp M_WHIP_RENDER_LOWER
    bne @compose
    lda $08
    cmp M_BODY_SPRITE_LO
    bne @compose
    lda $09
    cmp M_BODY_SPRITE_HI
    beq @cached
@compose:
    stx M_WHIP_SPRITE_PHASE
    lda M_WHIP_LOWER
    sta M_WHIP_RENDER_LOWER
    lda $08
    sta M_BODY_SPRITE_LO
    lda $09
    sta M_BODY_SPRITE_HI
    lda WhipSprites,x
    sta $10
    lda WhipSprites+1,x
    sta $11
    ldy #0
    lda ($08),y
    asl
    asl
    tay
@body:
    lda ($08),y
    sta M_PLAYER_SPRITE,y
    dey
    bpl @body
    lda M_PLAYER_SPRITE
    asl
    asl
    tax
    inx
    ldy #0
    lda ($10),y
    sta $12
    clc
    adc M_PLAYER_SPRITE
    sta M_PLAYER_SPRITE
    lda $12
    asl
    asl
    clc
    adc #1
    sta $12
    iny
@whip:
    tya
    and #3
    cmp #1
    bne @whipByte
    lda M_WHIP_LOWER
    asl                       ; native Y encodes twice the displacement
    clc
    adc ($10),y
    jmp @storeWhip
@whipByte:
    lda ($10),y
@storeWhip:
    sta M_PLAYER_SPRITE,x
    inx
    iny
    cpy $12
    bne @whip
@cached:
    lda #<M_PLAYER_SPRITE
    sta $08
    lda #>M_PLAYER_SPRITE
    sta $09
    rts

WhipSprites: .word SmallWhipBack,SmallWhipForward,BigWhipBack,BigWhipForward
; Original Castlevania whip tiles copied after Mario's CHR. Y offsets are
; stored at twice their actual displacement, as the native renderer expects.
SmallWhipBack: .byte 2,$E0,92,$41,$F4,0,94,$41,$F4
SmallWhipForward: .byte 3,$F4,100,$41,8,$F4,100,$41,16,$F4,102,$41,24
BigWhipBack: .byte 2,$C8,104,$41,$F4,$E8,106,$41,$F4
BigWhipForward: .byte 5,$DC,112,$41,8,$DC,112,$41,16,$DC,112,$41,24,$DC,112,$41,32,$DC,114,$41,40

MarioSprites:
    .word SmallWalk1,SmallWalk2,SmallWalk3,SmallStand,SmallJump
    .word BigWalk1,BigWalk2,BigWalk3,BigStand,BigJump
    .word SmallSkid,BigSkid
    .word SmallDead
    .word BigCrouch
.macro smallSprite name, left, right
name:
    .byte 2,0,left,0,$F8,0,right,0,0
.endmacro
.macro bigSprite name, ul, ur, ll, lr
name:
    .byte 4,$E0,ul,0,$F8,$E0,ur,0,0,0,ll,0,$F8,0,lr,0,0
.endmacro
smallSprite SmallWalk1,0,2
smallSprite SmallWalk2,4,6
smallSprite SmallWalk3,8,10
smallSprite SmallStand,12,14
smallSprite SmallJump,16,18
bigSprite BigWalk1,20,22,24,26
bigSprite BigWalk2,28,30,32,34
bigSprite BigWalk3,36,38,40,42
bigSprite BigStand,44,46,48,50
bigSprite BigJump,52,54,56,58
smallSprite SmallSkid,76,78
bigSprite BigSkid,80,82,84,86
smallSprite SmallDead,88,90
BigCrouch: .byte 4,$F0,116,0,$F8,$F0,118,0,0,$10,120,0,$F8,$10,120,$40,0
BlankSprite: .byte 0
FireSprite1: .byte 1,0,60,0,$FC
FireSprite2: .byte 1,0,62,0,$FC
ItemSprites: .word MushroomSprite,FlowerSprite,HeartSprite
MushroomSprite: .byte 2,$F0,64,0,$F8,$F0,66,0,0
FlowerSprite: .byte 2,$F0,68,0,$F8,$F0,68,$40,0
HeartSprite: .byte 1,$F0,70,3,$FC
CandleSprite1: .byte 1,$F0,72,3,$FC
CandleSprite2: .byte 1,$F0,74,3,$FC

; Exact native OAM permutation, replacing repeated addition/wrap loops.
NextOamIndex:
.repeat 256, i
    .if ((i+$C4) & $FF) >= $44
        .byte ((i+$C4) & $FF)
    .elseif ((i+2*$C4) & $FF) >= $44
        .byte ((i+2*$C4) & $FF)
    .else
        .byte ((i+3*$C4) & $FF)
    .endif
.endrepeat

.segment "FIXED"
FarInteractions:
    ldy #5
    jsr $C1D6
    jsr Interactions
FarScriptedAi:
    jsr $E8F0
    jmp PostNativeAi           ; native fish-man routines may leave bank 6 mapped

ResetMario:
    lda $27
    pha
    ldy #6
    jsr $C1D6
    jsr InitializeMario
    pla
    tay
    jsr $C1D6
    lda #$40
    sta $44
    rts

.segment "BANK5"
Interactions:
    lda #2
    sta $70
    lda M_POWER
    cmp #3
    bcc @validPower
    lda #2
    sta M_POWER
@validPower:
    lda M_INVINCIBLE
    beq @timerDone
    dec M_INVINCIBLE
@timerDone:
    lda $28
    cmp M_LAST_STAGE
    beq @sameStage
    sta M_LAST_STAGE
    lda #$FF
    sta M_PALETTE
    lda #0
    sta M_FB_ACTIVE
    sta M_FB_ACTIVE+1
    sta M_WHIP_TIMER
    sta M_WHIP_BRICK_PENDING
    ldx #27
@clearStage:
    sta M_CANDLE_FLAGS,x
    sta M_DROP_KIND,x
    dex
    bpl @clearStage
@sameStage:
    jsr ConvertWhipDrops
    jsr ItemInteractions
    jsr UpdateBodySize
    jsr StompEnemies
    jsr WhipUpdate
    jsr Fireballs
    jsr PlayerPalette
    rts

ConvertWhipDrops:
    ldx #3
@loop:
    lda $0434,x
    cmp #$2F                  ; only native pickup AI 2F..31 needs inspection
    bcc @next
    cmp #$32
    bcs @next
@check:
    lda $0584,x
    and #$0F
    cmp #3
    bne @next
    lda M_DROP_KIND,x
    bne @next                 ; do not restart an existing custom pickup
@convert:
    lda #0
    sta $72                    ; release native special-pickup reservation
    stx M_ACTOR
    jsr MakeMarioDrop
@next:
    inx
    cpx #20
    bne @loop
    rts

.segment "FIXED"
; These hooks are also called by native doors and stair scenes in bank 6.
ActorEnd:
    lda M_DROP_KIND,x
    beq @native
    jmp $E92B
@native:
    lda $0434,x
    jmp $E9E9

CollisionSetup:
    lda #$FF
    sta $5C                    ; no whip collision
    lda #6
    ldy M_BODY_TALL
    beq @height
    asl
@height:
    sta $5F
    rts

GetPlayerCollisionY:
    ; Both callers enter with carry clear after their horizontal CMP.
    ; Match SMB's feet-aligned 24px standing and 12px small/crouched boxes.
    lda #4
    ldy M_BODY_TALL
    bne @add
    lda #10
@add:
    adc $3F
    rts

MarioDamage:
    lda $18
    cmp #5
    bne @done                 ; scripted transitions cannot hurt the player
    ldy #5
    jsr $C1D6                 ; native AI can reach contact damage from bank 6
    jmp GameplayDamage
@done:
    rts

.segment "AIBRIDGE"
; The displaced native damage body now lives in bank 5. Keep shared callers
; in fixed ROM, so a fish-man splash, projectile or stair room reload cannot
; send execution into the wrong bank after native AI returns.
PostNativeAi:
    ldy #5
    jsr $C1D6
    jsr ConvertWhipDrops
    jsr PlayerPalette
    ldy #6
    jmp $C1D6

; A previous actor can leave bank 6 selected for splash/projectile helpers.
; Each active actor starts its native dispatch in the bank its table expects.
PrepareActorBank:
    ldy #5
    jsr $C1D6
    lda $E9C9
    jmp $E952                 ; displaced push of the native actor continuation

.segment "BANK5"
NativeHealthDamage:
    ldx $4E
    jsr $FC97                 ; original knockback/stair stun, returns in bank 5
    ldx $4E
    lda #$10
    ldy $2B
    bne @damage
    ldy $28
    cpy #$0C
    bcs @damage
    lda #$0C
    cpy #7
    bcs @damage
    lda #8
@damage:
    sta $4B
    lda $45
    bmi @done
    sec
    sbc $4B
    sta $45
@done:
    rts

GameplayDamage:
    lda M_DROP_KIND,x
    bne @done
    jsr ContactStomp
    bcs @done
    lda M_INVINCIBLE
    bne @done
    jsr $FE96                 ; original hit sound, knockback and stage damage
    jsr NativeHealthDamage
    lda $45
    bpl @healthReady
    lda #0
    sta $45                   ; clamp lethal damage instead of unsigned wrap
@healthReady:
    lda $45
    cmp #17
    bcs @keepPower            ; only the final quarter of native HP shrinks
    lda #0
    sta M_POWER
    sta M_CROUCH
    sta M_BODY_TALL
@keepPower:
    lda #0
    sta M_WHIP_TIMER
    sta M_WHIP_BRICK_PENDING
    lda #96
    sta M_INVINCIBLE
    lda #$30
    sta $5B
@done:
    rts

WhipUpdate:
    lda $046C
    beq @allowed
    cmp #1
    beq @allowed
    cmp #3                    ; native Down crouch supports the lowered whip
    beq @allowed
    cmp #4
    beq @allowed
    cmp #7
    beq @allowed
    lda #0
    sta M_WHIP_TIMER
    sta M_WHIP_BRICK_PENDING
    rts
@allowed:
    lda M_WHIP_TIMER
    beq @input
    dec M_WHIP_TIMER
    jmp @shape
@input:
    lda M_HELD
    and #8
    bne @done                 ; Up+B belongs to the native subweapon
    lda $F5
    and #$40
    beq @done
    lda #24
    sta M_WHIP_TIMER
    lda #$0A
    ldx M_POWER
    beq @sound
    lda #9
@sound:
    jsr $C1A7
@shape:
    lda #0
    sta M_WHIP_LOWER
    lda $046C
    beq @duckInput
    cmp #3
    bne @height
@duckInput:
    lda M_HELD
    and #4
    beq @height
    lda #4
    ldx M_POWER
    beq @lower
    lda #8
@lower:
    sta M_WHIP_LOWER
@height:
    lda $3F
    ldx M_POWER
    bne @big
    clc
    adc #8
    ldx #24
    bne @size
@big:
    sec
    sbc #4
    ldx #40
@size:
    stx M_WHIP_LENGTH
    clc
    adc M_WHIP_LOWER
    sta M_WHIP_Y
    lda M_WHIP_TIMER
    cmp #12                   ; one fully extended strike per swing
    bne @done
    jsr QueueWhipWall
    jmp WhipActors
@done:
    rts

QueueWhipWall:
    lda #1
    sta M_WHIP_BRICK_PENDING
    lda M_WHIP_Y
    sta M_WHIP_BRICK_Y
    lda M_WHIP_LENGTH
    lsr
    sta M_WHIP_HALF
    clc
    adc #8
    sta M_TEMP
    lda $41
    sta M_WHIP_BRICK_PAGE
    lda $0450
    bne @left
    lda $40
    clc
    adc M_TEMP
    bcc @x
    inc M_WHIP_BRICK_PAGE
    bne @x
@left:
    lda $40
    sec
    sbc M_TEMP
    bcs @x
    dec M_WHIP_BRICK_PAGE
@x:
    sta M_WHIP_BRICK_X
    rts

WhipActors:
    ldx #3
@loop:
    lda $0434,x
    jeq @next                 ; empty slots cannot be hit
    cmp #$28
    bcc @enemy
    cmp #$2F
    jcs @next
    lda $0300,x
    bne @next
    lda #16
    sta M_TEMP
    sta M_TEMP2
    bne @bounds
@enemy:
    jsr EnemyBounds
    bcc @next
@bounds:
    lda M_TEMP
    clc
    adc M_WHIP_LENGTH
    sta M_TEMP
    lda M_TEMP2
    clc
    adc #4
    sta M_TEMP2
    lda $0450
    bne @left
    lda $038C,x
    cmp $038C
    bcc @next
    sec
    sbc $038C
    jmp @dx
@left:
    lda $038C
    cmp $038C,x
    bcc @next
    sec
    sbc $038C,x
@dx:
    cmp M_TEMP
    bcs @next
    lda $0354,x
    sec
    sbc M_WHIP_Y
    bcs @dy
    eor #$FF
    adc #1
@dy:
    cmp M_TEMP2
    bcs @next
    stx M_ACTOR
    lda $0434,x
    cmp #$28
    bcc @hitEnemy
    jsr ReleaseCandle
    jmp @hit
@hitEnemy:
    lda #6                    ; original leather-whip damage
    ldy M_POWER
    beq @damage
    lda #8
@damage:
    jsr HitEnemyWithDamage
@hit:
    inc M_WHIP_HIT_COUNTER
    ldx M_ACTOR
@next:
    inx
    cpx #23
    bcs @done
    jmp @loop
@done:
    rts

ReleaseCandle:
    stx M_ACTOR
    jsr $E3D7
    ldx M_ACTOR
    lda M_POWER
    cmp #2
    bcc MakeMarioDrop
    lda $0584,x
    cmp #8
    beq @native
    cmp #9
    beq @native
    cmp #$0B
    beq @native
    cmp #$0D
    beq @native
    cmp #$0F
    bne MakeMarioDrop
@native:
    lda #0
    sta M_DROP_KIND,x
    sta M_CANDLE_FLAGS,x
    rts
MakeMarioDrop:
    lda M_POWER
    cmp #2
    bcc @upgrade
    lda #2
@upgrade:
    clc
    adc #1
    sta M_DROP_KIND,x
    lda #160
    sta M_DROP_TIMER,x
    lda #4
    sta $0434,x               ; native inert actor, reserved until collected
    lda #0
    sta $0300,x
    sta $046C,x
    sta $0450,x
    sta $0338,x
    lda $0354,x
    sec
    sbc #8
    sta $0354,x
    lda #$0D
    jsr $C1A7
    ldx M_ACTOR
    rts

ItemInteractions:
    ldx #3
@loop:
    lda M_DROP_KIND,x
    jeq @next
    lda $0434,x
    cmp #4
    jne @stale
    stx M_ACTOR
    jsr $DD14                  ; follow the native camera movement
    ldx M_ACTOR
    dec M_DROP_TIMER,x
    jeq @erase
    lda M_DROP_TIMER,x
    cmp #145
    bcc @fall
    dec $0354,x                ; emerge upward for fifteen frames
    jmp @pickup
@fall:
    lda $038C,x
    sta M_POINT_X
    lda $0354,x
    clc
    adc #8
    sta M_POINT_Y
    jsr TileAtPoint
    ldx M_ACTOR
    cmp #0
    bne @ground
    lda $0354,x
    clc
    adc #2
    sta $0354,x
    cmp #224
    bcs @erase
    jmp @pickup
@ground:
    lda M_DROP_KIND,x
    cmp #1
    bne @pickup
    inc $038C,x                ; mushrooms walk to the right
@pickup:
    lda $0300,x
    bne @next
    lda $038C,x
    sec
    sbc $038C
    bcs @dx
    eor #$FF
    adc #1
@dx:
    cmp #14
    bcs @next
    jsr GetPlayerCollisionY
    sec
    sbc $0354,x
    bcs @dy
    eor #$FF
    adc #1
@dy:
    cmp #19
    bcs @next
    lda M_DROP_KIND,x
    cmp #3
    bcs @heart
    cmp M_POWER
    bcc @reward
    sta M_POWER
    lda #30
    sta M_INVINCIBLE
@reward:
    inc M_PICKUP_COUNTER
    lda #$17
    jsr $C1A7
    ldx M_ACTOR
    jmp @erase
@heart:
    lda $71
    cmp #99
    bcs @heartFull
    inc $71
@heartFull:
    jsr $FCD0                 ; redraw native heart counter, returns to bank 5
    inc M_PICKUP_COUNTER
    lda #$16                  ; native heart pickup sound
    jsr $C1A7
    ldx M_ACTOR
    jmp @erase
@erase:
    lda #0
    sta M_DROP_KIND,x
    sta $0434,x
    sta $031C,x
    lda #$F4
    sta $0354,x
    jmp @next
@stale:
    ; A native spawn reused this slot: forget our pickup, preserve the spawn.
    lda #0
    sta M_DROP_KIND,x
    sta M_DROP_TIMER,x
@next:
    inx
    cpx #23
    bcs @done
    jmp @loop
@done:
    rts

TileAtPoint:
    lda M_POINT_X
    clc
    adc $2E
    sta $12
    lda $2F
    adc #0
    ldx $28
    clc
    adc $FBD6,x               ; native stage's collision-map page parity
    and #1
    sta $13
    lda M_POINT_Y
    and #$F8
    sec
    sbc #$30
    cmp #$B0
    bcs @empty
    sta $10
    lda $12
    lsr
    lsr
    lsr
    lsr
    lsr
    clc
    adc $10
    tay
    lda $13
    beq @firstPage
    lda $0650,y
    jmp @unpack
@firstPage:
    lda $05A0,y
@unpack:
    tax
    lda $12
    and #$18
    beq @six
    cmp #8
    beq @four
    cmp #16
    beq @two
    txa
    jmp @mask
@six:
    txa
    lsr
    lsr
    jmp @shiftFour
@four:
    txa
@shiftFour:
    lsr
    lsr
@shiftTwo:
    lsr
    lsr
@mask:
    and #3
    sta $14
    jmp TileAtPointReturn
@two:
    txa
    jmp @shiftTwo
@empty:
    lda #0
    sta $14
TileAtPointReturn:
    rts

StompEnemies:
    lda $046C
    cmp #1
    jne @done
    lda M_VY_HI
    jmi @done
    ldx #3
@loop:
    jsr EnemyBounds
    jcc @next
    lda $038C,x
    sec
    sbc $038C
    bcs @dx
    eor #$FF
    adc #1
@dx:
    cmp M_TEMP
    bcs @next
    lda $0354,x
    sec
    sbc M_TEMP2
    sta M_BOTTOM              ; enemy top
    lda M_PREV_Y
    clc
    adc #16
    cmp M_BOTTOM
    bcc @previousAbove
    beq @previousAbove
    jmp @next
@previousAbove:
    lda $3F
    clc
    adc #16
    cmp M_BOTTOM
    bcc @next
    jsr StompEnemy
    rts
@next:
    inx
    cpx #20
    bcs @done
    jmp @loop
@done:
    rts

ContactStomp:
    lda $046C
    cmp #1
    bne @no
    lda M_VY_HI
    bmi @no
    jsr EnemyBounds
    bcc @no
    lda $0354,x
    sec
    sbc M_TEMP2
    clc
    adc #4
    sta M_BOTTOM
    lda M_PREV_Y
    clc
    adc #16
    cmp M_BOTTOM
    bcs @no
    jsr StompEnemy
    sec
    rts
@no:
    clc
    rts

StompEnemy:
    stx M_ACTOR
    jsr HitEnemy
    lda #$FC
    sta M_VY_HI
    lda #0
    sta $0514
    lda #1
    sta $046C
    inc M_STOMP_COUNTER
    rts

EnemyBounds:
    lda $0434,x
    beq @no
    cmp #$28
    bcs @no
    cmp #$17
    beq @no                   ; native player subweapons are friendly actors
    tay
    lda $0300,x
    beq @visible
    cpy #4
    bne @no                   ; native AI 4 can be a hidden boss hitbox
@visible:
    lda M_DROP_KIND,x
    bne @no                   ; custom pickups reserve inert native AI 4
    lda $0488,x
    bpl @bounds
    lda $0568,x               ; animation holds also use bit 7 of $0488
    bne @no                   ; genuine hurt cooldowns have a live hit timer
@bounds:
    tya
    asl
    tay
    lda $E46A,y
    clc
    adc #7
    sta M_TEMP
    lda $E46B,y
    sta M_TEMP2
    sec
    rts
@no:
    clc
    rts

HitEnemy:
    lda #8
HitEnemyWithDamage:
    sta $0D
    stx $4E
    lda #0
    sta $0C
    lda #$FF
    sta $0E
    jsr $E573                 ; native enemy / boss damage dispatcher
    ldx M_ACTOR
    rts

Fireballs:
    lda M_HELD
    and #8
    bne @update
    lda M_POWER
    cmp #2
    bne @update
    lda M_CROUCH
    bne @update               ; original SMB cannot throw while crouching
    lda $F5
    and #$40
    beq @update
    ldx #0
    lda M_FB_ACTIVE
    beq @spawn
    inx
    lda M_FB_ACTIVE+1
    bne @update
@spawn:
    lda #1
    sta M_FB_ACTIVE,x
    lda #100
    sta M_FB_LIFE,x
    lda $0450
    sta M_FB_DIRECTION,x
    lda $038C                 ; center anchor = SMB sprite-left + 8
    sta M_FB_X,x
    lda $3F
    sec
    sbc #16                   ; original SMB launches at the player's raw Y
    sta M_FB_Y,x
    lda #4                     ; SMB fireball initial downward velocity
    sta M_FB_VY,x
    lda #0
    sta M_FB_FORCE,x
    sta M_FB_YFRAC,x
@update:
    ldx #0
@loop:
    stx M_PROJECTILE
    lda M_FB_ACTIVE,x
    bne @active
    jmp @hide
@active:
    dec M_FB_LIFE,x
    bne @move
    jmp @erase
@move:
    lda M_FB_X,x
    clc
    adc $49
    sta M_FB_X,x
    lda M_FB_DIRECTION,x
    bne @left
    lda M_FB_X,x
    clc
    adc #4
    jmp @x
@left:
    lda M_FB_X,x
    sec
    sbc #4
@x:
    sta M_FB_X,x
    cmp #8
    bcs @rightBound
    jmp @erase
@rightBound:
    cmp #248
    bcc @gravity
    jmp @erase
@gravity:
    ; Same old-velocity integration order as SMB's ImposeGravity.
    lda M_FB_YFRAC,x
    clc
    adc M_FB_FORCE,x
    sta M_FB_YFRAC,x
    lda M_FB_Y,x
    adc M_FB_VY,x
    sta M_FB_Y,x
    lda M_FB_FORCE,x
    clc
    adc #$50
    sta M_FB_FORCE,x
    lda M_FB_VY,x
    adc #0
    sta M_FB_VY,x
    cmp #3
    bmi @yBound
    lda M_FB_FORCE,x
    cmp #$80
    bcc @yBound
    lda #3
    sta M_FB_VY,x
    lda #0
    sta M_FB_FORCE,x
@yBound:
    lda M_FB_Y,x
    cmp #224
    bcc @floor
    jmp @erase
@floor:
    lda M_FB_X,x
    sta M_POINT_X
    lda M_FB_Y,x
    clc
    adc #8
    sta M_POINT_Y
    lda M_FB_VY,x
    bmi @wall
    jsr TileAtPoint
    ldx M_PROJECTILE
    cmp #0
    beq @wall
    jsr QueueFireballTerrain
    lda M_POINT_Y
    and #$F8
    sec
    sbc #8
    sta M_FB_Y,x
    lda #$FD
    sta M_FB_VY,x
@wall:
    lda M_FB_Y,x
    clc
    adc #3
    sta M_POINT_Y
    jsr TileAtPoint
    ldx M_PROJECTILE
    cmp #0
    beq @objects
    jsr QueueFireballTerrain
    jmp @erase
@objects:
    ldx #3
@actorLoop:
    lda $0434,x
    jeq @nextActor            ; avoid bounds work for every empty slot
    cmp #$2F
    jcs @nextActor
    ; Largest native enemy X radius is 20, plus our seven-pixel allowance.
    ; Candles use 16. Reject distant actors before class/cooldown/Y checks.
    ldy M_PROJECTILE
    lda M_FB_X,y
    sec
    sbc $038C,x
    bcs @distance
    eor #$FF
    adc #1
@distance:
    cmp #28
    jcs @nextActor
    sta M_FB_DISTANCE_X
    lda $0434,x
    cmp #$28
    bcc @enemy
    cmp #$2F
    bcs @nextActor
    lda $0300,x
    bne @nextActor            ; candles must be visible; EnemyBounds handles enemies
    lda #16
    sta M_TEMP
    sta M_TEMP2
    jmp @collision
@enemy:
    jsr EnemyBounds
    bcc @nextActor
@collision:
    stx M_ACTOR
    ldy M_PROJECTILE
    lda M_FB_DISTANCE_X
    cmp M_TEMP
    bcs @nextActor
    lda M_FB_Y,y
    clc
    adc #4
    sec
    sbc $0354,x
    bcs @dy
    eor #$FF
    adc #1
@dy:
    cmp M_TEMP2
    bcs @nextActor
    lda $0434,x
    cmp #$28
    bcc @hitEnemy
    jsr ReleaseCandle
    jmp @hitDone
@hitEnemy:
    jsr HitEnemy
@hitDone:
    inc M_FIRE_HIT_COUNTER
    ldx M_PROJECTILE
    jmp @erase
@nextActor:
    inx
    cpx #23
    bcs @render
    jmp @actorLoop
@render:
    ldx M_PROJECTILE
    lda M_FB_X,x
    sta $038D,x
    lda M_FB_Y,x
    sta $0355,x
    lda #0
    sta $0301,x
    sta $0451,x
    jmp @next
@erase:
    lda #0
    sta M_FB_ACTIVE,x
@hide:
    lda #$F4
    sta $0355,x
@next:
    inx
    cpx #2
    bcs @done
    jmp @loop
@done:
    rts

QueueFireballTerrain:
    lda M_FB_BRICK_PENDING,x
    bne @done                 ; retain the first surface touched this frame
    lda #1
    sta M_FB_BRICK_PENDING,x
    lda M_FB_X,x
    clc
    adc $2E
    sta M_FB_BRICK_X,x
    lda $2F
    adc #0
    sta M_FB_BRICK_PAGE,x
    lda M_FB_Y,x
    clc
    adc #4
    sta M_FB_BRICK_Y,x
@done:
    rts

PlayerPalette:
    lda M_POWER
    cmp M_PALETTE
    beq @done
    sta M_PALETTE
    lda #1
    jsr $CCF0
    lda #$3F
    jsr $CCF2
    lda #$11
    jsr $CCF2
    ldy #0
    lda M_POWER
    cmp #2
    bne @colors
    ldy #3
@colors:
    lda PlayerColors,y
    sta M_NATIVE_PALETTE+3     ; native stair/room reloads reuse current Mario colors
    jsr $CCF2
    iny
    lda PlayerColors,y
    sta M_NATIVE_PALETTE+4
    jsr $CCF2
    iny
    lda PlayerColors,y
    sta M_NATIVE_PALETTE+5
    jsr $CCF2
    lda #$FF
    jsr $CCF2
@done:
    rts
PlayerColors: .byte $16,$27,$18,$37,$27,$16

.export DraculaCooldown, DraculaHeadCooldown
DraculaCooldown:
    ; AI 4 is inert, so its hidden head never runs native $EEA7 itself.
    ; Tick it once from Dracula's body AI, in both forms, then retain the
    ; original body cooldown call and its native early-return behavior.
    lda $0570
    beq @body
    dec $0570
    bne @body
    lda $0490
    and #$7F
    sta $0490
@body:
    jmp $EEA7

DraculaHeadCooldown:
    ; The second form's native damage handler marks only the body. Mirror
    ; that timer to its hidden head for Mario's weapon collision checks.
    sta $0570
    lda $0490
    ora #$80
    sta $0490
    lda $048F                 ; displaced native instruction at $E38C
    rts

.segment "HUDIRQ"
; The original HUD predicate/reset/update remains at F87D..F8C6. Replace
; its scanline-40 polling wait with MMC5's raster IRQ, freeing that interval
; for normal game logic. Cache the displayed frame before camera AI runs.
ArmHudSplit:
    lda $FD
    sta M_SPLIT_X
    jsr $F912
    eor $2F
    and #1
    lsr
    lda $FF
    and #$FE
    adc #0
    sta $FF
    sta M_SPLIT_CTRL
    lda #1
    sta M_SPLIT_ARMED
    lda #40
    sta $5203
    lda #$80
    sta $5204
    cli
    rts

HudIrq:
    pha
    lda $5204                 ; acknowledge the mapper's scanline IRQ
    lda #0
    sta $5204
    sta M_SPLIT_ARMED
    bit $2002
    lda M_SPLIT_X
    sta $2005
    lda $FC
    sta $2005
    lda M_SPLIT_CTRL
    sta $2000
    pla
    rti

.segment "AIBRIDGE"
MainLoopIrq:
    cli                       ; IRQ must remain available between short NMIs
    jmp $C030

.segment "FIXED"
FinishHudSetup:
    lda M_SPLIT_ARMED
    bne @done
    jmp $C11F
@done:
    rts

.setcpu "6502"
.macpack longbranch
.include "art.inc"
.export InitBridge,DrawBridge,UpdateBridge,RosterBridge,MenuPaletteBridge,ColourBridge
.export ChoiceMaxBridge,ChoiceLimitBridge,PortraitBridge,MenuInfoBridge,NameBridge
.export ControlBridge
.export Init,Draw,Update,Roster,MenuPalette,FireHit,Spawn,SelectPose
.export Prepare,StageDirectional,PatternCopy,ConstrainHumanPositions,ConstrainRing
TTL=$04B0
FX=$04B4
FY=$04B8
HEIGHT=$04BC
VELOCITY=$04C0
DIR=$04C4
OWNER=$04C8
COOL=$04CC
HITWAIT=$04CE
ATTACK=$04D0
ATIME=$04D2
LASTX=$04D4
LASTY=$04D6
POSE=$04D8
PLAYER=$04DA
SHOT=$04DB
OAMP=$04DC
BASEX=$04DD
BASEY=$04DE
ATTR=$04DF
TILE=$04E0
CELL=$04E1
MAPINDEX=$04E2
SAVEDX=$04E3
TMP=$04E4
ACTIVE=$04E5
WALKDIR=$04E6
SAVEDA=$04E8
CUSTOM=$04E9
GROUPS=$04EA
CELLATTR=$04EC
DRAW_MAP=$04ED
DRAW_X=$04EF
DRAW_Y=$04F1
DRAW_ATTR=$04F3
MENU_CPU=$04F5
PIN_ACTIVE=$04F6
CONTROL_X=$04F8
CONTROL_Y=$04F9
CONTROL_SKIP=$04FA
CACHE_BODY=$6000
CACHE_FIRE=$6060
STREAM_POSE=$6100
STREAM_BASE=$6102
STREAM_REQUEST=$6110
RESOLVED_ACTION=$6112
WALKING=$6114
STREAM_READY=$6104
MOVED_X=$6106
BUILD_MAP=$6108
BUILD_CELL=$6109
BUILD_TILE=$610A
BUILD_ATTR=$610B
BUILD_X=$610C
BUILD_Y=$610D
.segment "BRIDGE"
InitBridge:
 jsr $D1A5
 lda #4
 ldy #0
 jsr $FF00
 ; Rejoin the native setup at its original late-vblank phase, before
 ; its fixed-delay first HUD reveal.
@vblank:
 bit $2002
 bpl @vblank
 ldx #212
 jsr $FF2D
 rts
DrawBridge:
 lda $012D
 cmp #$FF
 beq @native
 lda $012E
 cmp #$FF
 bne @custom
@native:
 jsr $A62E
@custom:
 lda #4
 ldy #3
 jmp $FF00
UpdateBridge:
 lda #4
 ldy #6
 jsr $FF00
 jmp $A24A
RosterBridge:
 lda #4
 ldy #9
 jsr $FF00
 jmp $9F6F
MenuPaletteBridge:
 lda #4
 ldy #12
 jmp $FF00
ColourBridge:
 jmp $D284
PortraitBridge:
 sta SAVEDA
 lda #4
 ldy #18
 jsr $FF00
 lda CUSTOM
 bne @done
 ldx SAVEDA
 jmp $8DB6
@done:
 rts
MenuInfoBridge:
 lda #4
 ldy #21
 jmp $FF00
NameBridge:
 stx SAVEDA
 lda #4
 ldy #24
 jsr $FF00
 jmp $D612
ChoiceMaxBridge:
 jsr ChoiceLimit
 sec
 sbc #1
 sta $6D
 jmp $A005
ChoiceLimitBridge:
 jsr ChoiceLimit
 cmp $6D
 beq @zero
 bcc @zero
 jmp $A017
@zero:
 jmp $A013
ChoiceLimit:
 lda $0100
 cmp #1
 bne @two
 lda $012B
 cmp #$FF
 bne @two
 lda #6
 rts
@two:
 lda #2
 rts
ControlBridge:
 stx CONTROL_X
 sty CONTROL_Y
 lda #4
 ldy #27
 jsr $FF00
 ldx CONTROL_X
 ldy CONTROL_Y
 lda CONTROL_SKIP
 bne @done
 lda $CB,x
 bne @done
 jmp $AF52
@done:
 rts
.segment "CODE"
 jmp Init
 jmp Draw
 jmp Update
 jmp Roster
 jmp MenuPalette
 jmp PaletteRam
 jmp Portrait
 jmp MenuInfo
 jmp Name
 jmp Control
 jmp CopyNativeOam
; Native WRAM $0400-$04AF was the sprite sorting workspace. Reserve the
; following unused $50 bytes, never borrowing audio, stack or bank state.
Init:
 lda #0
 ldx #$4F
@clear:
 sta $04B0,x
 dex
 bpl @clear
 ldx #$1F
@streamClear:
 sta $6100,x
 dex
 bpl @streamClear
 ldx #0
@cacheClear:
 sta $6000,x
 inx
 bne @cacheClear
 lda #1
 sta ACTIVE
 ldx #0
@prev:
 lda $2C,x
 sta LASTX,x
 lda $2E,x
 sta LASTY,x
 inx
 cpx #2
 bne @prev
 ; Keep every native ring/rope pattern intact. Human body and fireball
 ; patterns now travel in the existing alternating wrestler packets.
 jsr PaletteRam
 ; A fixed two-pixel marker keeps the native raster split independent
 ; of which letter begins the renamed right-hand wrestler label.
 lda #$0E
 sta $2006
 lda #$F0
 sta $2006
 lda #$A0
 sta $2007
 lda #0
 ldx #15
@marker:
 sta $2007
 dex
 bne @marker
 ; Native top scroll is $E8: screen row 88 maps to nametable row 10.
 lda #$21
 sta $2006
 lda #$56
 sta $2006
 lda #$EF
 sta $2007
 jmp Prepare
PaletteRam:
 ldx #0
@p:
 lda $012D,x
 cmp #$FF
 beq @next
 lda #16
 sta $86,x
 txa
 eor #1
 tay
 lda $2A,y
 sta TMP
 tya
 asl
 asl
 asl
 tay
 lda #$30
 sta $0391,y
 lda #$27
 sta $0392,y
 lda TMP
 beq @red
 lda #$1A
 bne @shade
@red:
 lda #$16
@shade:
 sta $0393,y
@next:
 inx
 cpx #2
 bne @p
 rts
Roster:
 ; The tournament keeps its six participants, each using either brother.
 ldy $0100
 lda $012B
 cmp #$FF
 bne :+
 ldy #2
:
 cpy #6
 bcs @done
 tya
@fill:
 sta $0125,y
 clc
 adc #1
 iny
 cpy #6
 bcc @fill
@done:
 rts
IsOpponentMenu:
 lda $0100
 cmp #1
 bne @human
 lda $012B
 cmp #$FF
 bne @human
 ; The native menu flips $012B to CPU selection while the confirmed
 ; human portrait is still sliding away. Keep the outgoing identity
 ; until the next portrait begins its entrance (phase zero).
 lda $18
 and #$7F
 cmp #2
 beq @visible
 lda #1
 sta MENU_CPU
@visible:
 lda MENU_CPU
 bne @cpu
 clc
 rts
@human:
 lda #0
 sta MENU_CPU
 clc
 rts
@cpu:
 sec
 rts
Portrait:
 lda #0
 sta CUSTOM
 lda $28
 cmp #$87
 bne @hud
 jsr IsOpponentMenu
 bcs @native
 bcc @mario
@hud:
 ldx #0
 lda $5F
 bne :+
 inx
:
 lda $012D,x
 cmp #$FF
 beq @native
@mario:
 lda #1
 sta CUSTOM
 lda #<PortraitData
 sta $1F
 lda #>PortraitData
 sta $20
 ldx #2
 ldy #0
@page:
 ; Keep the native eight-byte upload cadence. A per-byte branch here
 ; pushes the following timed menu split into the next video frame.
 .repeat 8
 lda ($1F),y
 sta $2007
 iny
 .endrepeat
 bne @page
 inc $20
 dex
 bne @page
@tail:
 .repeat 4
 lda ($1F),y
 sta $2007
 iny
 .endrepeat
 cpy #64
 bne @tail
 rts
@native:
 lda SAVEDA
 asl
 sta SAVEDA
 tay
 lda NativePortraits,y
 sta $1F
 lda NativePortraits+1,y
 sta $20
 rts
MenuInfo:
 lda $6D
 sta SAVEDA
 jsr IsOpponentMenu
 bcs @native
 lda #<MarioStats
 sta $1F
 lda #>MarioStats
 sta $20
 jmp @offset
@native:
 lda #<NativeStats
 sta $1F
 lda #>NativeStats
 sta $20
@offset:
 ldx SAVEDA
 beq @write
@advance:
 clc
 lda $1F
 adc #72
 sta $1F
 bcc :+
 inc $20
:
 dex
 bne @advance
@write:
 ldx #6
 ldy #0
 lda #$12
 sta TMP
@row:
 lda #$20
 sta $2006
 lda TMP
 sta $2006
 ; Match the original unrolled twelve-column writer, rather than
 ; spending a branch and counter update on every displayed letter.
 .repeat 12
 lda ($1F),y
 sta $2007
 iny
 .endrepeat
 clc
 lda TMP
 adc #32
 sta TMP
 dex
 bne @row
 jsr IsOpponentMenu
 bcc @colours
 lda #$3F
 sta $2006
 lda #1
 sta $2006
 lda #0
 sta $2007
 lda #$10
 sta $2007
 lda #$20
 sta $2007
 rts
@colours:
 jmp MenuPalette
Name:
 ldx SAVEDA
 lda $0125,x
 asl
 tay
 cpx $0100
 bcs @original
 lda MarioNames,y
 sta $1F
 lda MarioNames+1,y
 sta $20
 ldy #0
@copy:
 lda ($1F),y
 sta $0200,y
 iny
 cmp #0
 bne @copy
 lda #0
 sta $1F
 lda #2
 sta $20
 rts
@original:
 lda NativeNames,y
 sta $1F
 lda NativeNames+1,y
 sta $20
 rts
MenuPalette:
 ; Portrait palette 0, leaving the title, instructions and cursor intact.
 lda #$3F
 sta $2006
 lda #1
 sta $2006
 lda #$30
 sta $2007
 lda #$27
 sta $2007
 lda $6D
 beq :+
 lda #$1A
 bne @last
:
 lda #$16
@last:
 sta $2007
 rts

SelectPose:
 ; X is the native wrestler slot. Native scripted attacks/knockdowns win
 ; over walking. The reference front/back has two distinct moving feet.
 lda #0
 sta POSE,x
 lda PIN_ACTIVE,x
 beq :+
 lda #10
 jmp @save
:
 lda $CB,x
 beq :+
 lda #10
 jmp @save
:
 ; Controls enqueue actions for both bodies, but E2E8 resolves only one
 ; body per frame. In particular, Up/Down briefly request a jump script
 ; which is rejected into ordinary depth movement. Display the action
 ; latched after that body's script update, never the other body's new
 ; unprocessed request.
 ; Collision/fireball reactions are already committed for either body,
 ; including the body whose ordinary script will run next frame.
 txa
 eor #1
 tay
 lda $2A,y
 tay
 lda $3C,x
 cmp HurtAction,y
 beq @committed
 cmp HurtBack,y
 beq @committed
 cmp DownAction,y
 beq @committed
 lda RESOLVED_ACTION,x
@committed:
 cmp #5
 bcs @action
 lda ATIME,x
 beq :+
 lda ATTACK,x
 jmp @save
:
 lda #0
 sta WALKING,x
 ; The mat's depth movement advances every other frame. Read the held
 ; direction throughout that interval so a diagonal never alternates
 ; with side art, and a released direction keeps a still idle pose.
 ldy $012D,x
 lda $0D,y
 and #$0F
 beq @steady
 inc WALKING,x
 sta TMP
 and #$0C
 beq @horizontal
 and #8
 beq @front
 lda #2
 bne @depth
@front:
 lda #1
@depth:
 sta WALKDIR,x
 lda TMP
 and #3
 beq @steady
 lda WALKDIR,x
 ora #4
 sta WALKDIR,x
 bne @steady
@horizontal:
 lda #0
 sta WALKDIR,x
@steady:
 lda WALKDIR,x
 beq @side
 jmp @vertical
@side:
 lda WALKING,x
 beq @idle
 lda $8D
 lsr
 lsr
 lsr
 and #3
 cmp #3
 bne :+
 lda #1
:
 clc
 adc #1
 bne @save
@idle:
 lda ATIME,x
 beq @vertical
 lda ATTACK,x
 bne @save
@action:
 sta TMP
 txa
 eor #1
 tay
 lda $2A,y
 asl
 asl
 asl
 asl
 asl
 clc
 adc TMP
 tay
 lda Actions,y
 bne @save
@vertical:
 lda WALKDIR,x
 and #4
 beq @cardinal
 lda WALKDIR,x
 and #3
 cmp #2
 beq @backDiagonal
 lda #17
 bne @diagonalReady
@backDiagonal:
 lda #19
@diagonalReady:
 sta POSE,x
 lda WALKING,x
 beq @lastdir
 lda $8D
 and #8
 beq @lastdir
 inc POSE,x
 lda POSE,x
 rts
@cardinal:
 lda WALKDIR,x
 beq @lastdir
 cmp #2
 beq @back
 lda #11
 bne @steps
@back:
 lda #14
@steps:
 sta POSE,x
 lda WALKING,x
 beq @lastdir
@stride:
 lda $8D
 and #8
 beq :+
 inc POSE,x
:
 inc POSE,x
 rts
@lastdir:
 lda POSE,x
 rts
@save:
 sta POSE,x
 rts

Prepare:

 ; Prepare after native physics/CHR scripts, outside the timed top HUD.
 ; The following frame only needs OAM stores, with no pose calculations.
 jsr PaletteRam
 ; $71 has just advanced. E2E8 updated the opposite parity body; the
 ; other body's $3C can still contain an unprocessed controller request.
 lda $71
 and #1
 eor #1
 tax
 lda $3C,x
 sta RESOLVED_ACTION,x
 ldx #0
@select:
 lda $012D,x
 cmp #$FF
 beq @selectNext
 jsr SelectPose
 lda POSE,x
 sta STREAM_REQUEST,x
@selectNext:
 inx
 cpx #2
 bne @select
 jsr StageDirectional
 ldx #0
@actor:
 lda $012D,x
 cmp #$FF
 jeq @last
 lda STREAM_POSE,x
@effective:
 sta POSE,x
 lda POSE,x
 asl
 asl
 sta TMP
 asl
 clc
 adc TMP
 sta DRAW_MAP,x
 ; Native hurt art shifts its cells opposite these pose offsets. A fixed
 ; Mario body has no such compensation: applying them makes the whole
 ; character jump sideways/up on each flinch. Anchor hurt poses to the
 ; physical wrestler and retain genuine airborne height in $30.
 txa
 eor #1
 tay
 lda $2A,y
 tay
 lda $3C,x
 cmp HurtAction,y
 beq @hurt
 cmp HurtBack,y
 beq @hurt
 lda $2C,x
 clc
 adc $36,x
 sta DRAW_X,x
 lda $2E,x
 clc
 adc $38,x
 jmp @height
@hurt:
 lda $2C,x
 sta DRAW_X,x
 lda $2E,x
@height:
 sec
 sbc $42,x
 clc
 adc $30,x
 sec
 sbc #32
 sta DRAW_Y,x
 txa
 eor #1
 asl
 sta TMP
 lda $3A,x
 and #1
 beq :+
 lda TMP
 ora #$40
 sta TMP
:
 lda POSE,x
 cmp #11
 bcc :+
 cmp #17
 bcs @diagonalFlip
 lda TMP
 and #$BF
 sta TMP
 jmp :+
@diagonalFlip:
 ; The supplied diagonal sheet faces left; SMB's side art faces right.
 lda TMP
 eor #$40
 sta TMP
:
 lda TMP
 sta DRAW_ATTR,x
 jsr BuildBodyCache
@last:
 lda $2C,x
 sta LASTX,x
 lda $2E,x
 sta LASTY,x
 inx
 cpx #2
 beq :+
 jmp @actor
:
 jsr BuildFireCache
 rts

StageDirectional:
 ; Native phase 71 chooses both the next actor and its 20-tile upload
 ; buffer. Reuse that actor's existing packet, preserving the unrolled
 ; 320-byte PPU transfer and all original CPU wrestler packets.
 lda $27
 cmp #$FF
 jne @done
 lda $28
 cmp #$AB
 jne @done
 lda $71
 and #1
 tax
 lda $012D,x
 cmp #$FF
 jeq @done
 lda POSE,x
 sta STREAM_REQUEST,x
 sta STREAM_POSE,x
 tay
 lda StreamLo,y
 sta $17
 lda StreamHi,y
 sta $18
 ldy $71
 lda NativeChrBase,y
 sta STREAM_BASE,x
 lda #1
 sta STREAM_READY,x
 jmp StreamCopy
@done:
 rts

BuildBodyCache:
 stx PLAYER
 lda DRAW_MAP,x
 tay
 lda CacheLow,x
 tax
 lda #$F8
 .repeat 12,I
 sta CACHE_BODY+I*4,x
 .endrepeat
 lda DRAW_ATTR
 ldx PLAYER
 lda DRAW_ATTR,x
 sta BUILD_ATTR
 lda DRAW_X,x
 sta BUILD_X
 lda DRAW_Y,x
 sta BUILD_Y
 lda STREAM_BASE,x
 sta BUILD_TILE
 lda STREAM_READY,x
 bne :+
 rts
:
 lda CacheLow,x
 tax
 lda BUILD_ATTR
 and #$40
 jne @left
 .macro BuildCachedCell cell, col
 lda PoseMap,y
 cmp #$FF
 beq :+
 clc
 adc BUILD_TILE
 sta CACHE_BODY+cell*4+1,x
 lda PoseAttrs,y
 eor BUILD_ATTR
 sta CACHE_BODY+cell*4+2,x
 lda BUILD_X
 clc
 adc #col
 sta CACHE_BODY+cell*4+3,x
 lda BUILD_Y
 clc
 adc #(cell / 3)*8
 cmp #$66
 bcc :+
 cmp #$EF
 bcs :+
 sta CACHE_BODY+cell*4,x
:
 iny
 .endmacro
 .repeat 12,I
 BuildCachedCell I,(I .mod 3)*8
 .endrepeat
 ldx PLAYER
 rts
@left:
 .repeat 12,I
 BuildCachedCell I,16-(I .mod 3)*8
 .endrepeat
 ldx PLAYER
 rts

Control:
 lda #0
 sta CONTROL_SKIP
 ldx CONTROL_X
 lda $012D,x
 cmp #$FF
 bne :+
 rts
:
 txa
 eor #1
 tay
 lda PIN_ACTIVE,x
 beq @try
 lda $A2,y
 beq :+
 jmp @hold
:
 ; Native kick-out/recovery releases the hold and its input lock.
 lda #0
 sta PIN_ACTIVE,x
 sta $E7,x
 rts
@try:
 lda $A2,x
 beq :+
 rts
:
 lda $A2,y
 cmp #1
 beq :+
 rts
:
 ldy CONTROL_Y
 lda $0D,y
 and #$84
 cmp #$84
 beq :+
 rts
:
 ; Compare the displayed body anchors, including native pose offsets.
 txa
 eor #1
 tay
 lda $2C,x
 clc
 adc $36,x
 sta TMP
 lda $2C,y
 clc
 adc $36,y
 sec
 sbc TMP
 clc
 adc #36
 cmp #73
 bcs @done
 lda $2E,x
 clc
 adc $38,x
 sec
 sbc $42,x
 sta TMP
 lda $2E,y
 clc
 adc $38,y
 sec
 sbc $42,y
 sec
 sbc TMP
 clc
 adc #18
 cmp #37
 bcs @done
 lda #1
 sta PIN_ACTIVE,x
 ; Enter the native pin hold script. The native fallen-wrestler update
 ; starts its referee count, and the original kick-out logic stays live.
 lda $2C,y
 clc
 adc $36,y
 sta $2C,x
 lda $2E,y
 clc
 adc $38,y
 sec
 sbc $42,y
 clc
 adc $42,x
 sta $2E,x
 lda #0
 sta $36,x
 sta $38,x
 sta $30,x
 sta $3E,x
 sta $E0,x
 txa
 eor #1
 tay
 lda $2A,y
 tay
 lda PinAction,y
 sta $3C,x
 lda PinHold,y
 sta $40,x
@hold:
 lda #0
 sta $3E,x
 sta $E0,x
 lda #$FF
 sta $E7,x
 lda #1
 sta CONTROL_SKIP
@done:
 rts

CopyNativeOam:
 ; Preserve the exact native cell ordering for the original CPU body.
 ; The human body is replaced below, so copying it first wastes the HUD
 ; split's narrow cycle budget.
 lda #4
 sta $1C
 ldy #0
 lda $8D
 lsr
 bcc :+
 ldy #$4C
 lda #$FC
 sta $1C
:
 sty BUILD_CELL
 lda $D4
 bne @swap
 lda $D3
 bne @normal
 lda $CC
 bne @swap
 lda $CB
 bne @normal
 lda $2E
 cmp $2F
 bcc @swap
 beq @swap
@normal:
 lda #0
 sta GROUPS
 lda #$58
 sta GROUPS+1
 bne @copy
@swap:
 lda #$58
 sta GROUPS
 lda #0
 sta GROUPS+1
@copy:
 ldx #0
 lda $012D
 cmp #$FF
 beq @cpu0
 lda GROUPS+1
 clc
 adc BUILD_CELL
 tay
 ldx #0
@body1:
 .repeat 4,I
 lda $0450+I,x
 sta $0700+I,y
 .endrepeat
 tya
 clc
 adc $1C
 tay
 inx
 inx
 inx
 inx
 cpx #$50
 bcc @body1
 jmp @done
@cpu0:
 lda GROUPS
 clc
 adc BUILD_CELL
 tay
 ldx #0
@body0:
 .repeat 4,I
 lda $0400+I,x
 sta $0700+I,y
 .endrepeat
 tya
 clc
 adc $1C
 tay
 inx
 inx
 inx
 inx
 cpx #$50
 bcc @body0
@done:
 ; The following native effects begin with fresh indices.
 rts

Draw:
 lda #0
 sta GROUPS
 lda #$58
 sta GROUPS+1
 lda $D4
 bne @prioritySwap
 lda $D3
 bne @priorityDone
 lda $CC
 bne @prioritySwap
 lda $CB
 bne @priorityDone
 lda $2E
 cmp $2F
 bcc @prioritySwap
 bne @priorityDone
@prioritySwap:
 lda #$58
 sta GROUPS
 lda #0
 sta GROUPS+1
@priorityDone:
 ; Hide the original two 20-cell bodies and their dust cells, leaving
 ; native pin counts, ring bonuses and the HUD sprite-zero marker alone.

 ldx #0
@player:
 stx PLAYER
 lda $012D,x
 cmp #$FF
 bne :+
 jmp @skipplayer
:
 lda #16
 sta $86,x
 lda GROUPS,x
 tax
 ; This runs before the fixed scanline-88 HUD split. Unroll the OAM
 ; stores: the old per-cell bookkeeping could miss that split entirely.
 lda #$F8
 .repeat 8,I
 sta $0730+I*4,x
 .endrepeat
 ; Dust/shadow order follows Y alone, independently of pin/grapple
 ; body priority. Never erase the original opponent's shadow cells.
 ldy #$50
 lda $2E
 cmp $2F
 bcs :+
 ldy #$A8
:
 lda PLAYER
 beq :+
 tya
 eor #$F8
 tay
:
 lda #$F8
 sta $0700,y
 sta $0704,y
 lda PLAYER
 bne @cachePlayer1
 cpx #0
 jeq @cache00
 jmp @cache058
@cachePlayer1:
 cpx #0
 jeq @cache10
 jmp @cache158
 .macro CopyBodyCache actor, group
 .repeat 12,I
  lda CACHE_BODY+actor*48+I*4
  sta $0700+group+I*4
  cmp #$F8
  beq :+
  .repeat 3,J
   lda CACHE_BODY+actor*48+I*4+J+1
   sta $0700+group+I*4+J+1
  .endrepeat
:
 .endrepeat
 jmp @skipplayer
 .endmacro
@cache00:
 CopyBodyCache 0,0
@cache058:
 CopyBodyCache 0,$58
@cache10:
 CopyBodyCache 1,0
@cache158:
 CopyBodyCache 1,$58
@skipplayer:
 ldx PLAYER
 inx
 cpx #2
 beq :+
 jmp @player
:
 ; Only a short unrolled copy remains before the raster split.
 .repeat 4,I
  lda CACHE_FIRE+I*4
  sta $07F0+I*4
  cmp #$F8
  beq :+
  .repeat 3,J
   lda CACHE_FIRE+I*4+J+1
   sta $07F0+I*4+J+1
  .endrepeat
:
 .endrepeat
 rts

BuildFireCache:
 ldx #0
@fire:
 txa
 asl
 asl
 clc
 adc #$F0
 tay
 lda #$F8
 sta CACHE_FIRE-$F0,y
 lda TTL,x
 beq @fn
 lda FY,x
 sec
 sbc HEIGHT,x
 cmp #$66
 bcc @fn
 cmp #$EF
 bcs @fn
 sta CACHE_FIRE-$F0,y
 lda FX,x
 sta CACHE_FIRE-$F0+3,y
 lda TTL,x
 and #4
 beq :+
 lda #FIRE1
 bne @ft
:
 lda #FIRE0
@ft:
 sta TMP
 lda OWNER,x
 tax
 lda STREAM_BASE,x
 clc
 adc TMP
 sta CACHE_FIRE-$F0+1,y
 txa
 eor #1
 asl
 sta CACHE_FIRE-$F0+2,y
 tya
 sec
 sbc #$F0
 lsr
 lsr
 tax
@fn:
 inx
 cpx #4
 bne @fire
 rts

Update:
 lda $A6
 beq :+
 rts
:
 ldx #0
@timer:
 lda COOL,x
 beq :+
 dec COOL,x
:
 lda HITWAIT,x
 beq :+
 dec HITWAIT,x
:
 lda ATIME,x
 beq :+
 dec ATIME,x
:
 stx PLAYER
 lda $012D,x
 cmp #$FF
 beq @cpu
 tay
 lda $0E,y
 and #$C0
 beq @next
 pha
 lda #12
 sta ATIME,x
 pla
 and #$40
 beq @kick
 lda #4
 sta ATTACK,x
 jsr Spawn
 jmp @next
@kick:
 lda #5
 sta ATTACK,x
 jmp @next
@cpu:
 ; Original CPU wrestlers keep their own native move sets.
 jmp @next
@next:
 ldx PLAYER
 inx
 cpx #2
 beq :+
 jmp @timer
:
 ldx #0
@shots:
 stx SHOT
 lda TTL,x
 beq @sn
 dec TTL,x
 lda DIR,x
 beq @left
 lda FX,x
 clc
 adc #4
 bcs @kill
 cmp #$F0
 bcs @kill
 bcc @move
@left:
 lda FX,x
 sec
 sbc #4
 bcc @kill
 cmp #8
 bcc @kill
@move:
 cmp #8
 bcc @kill
 cmp #$F0
 bcs @kill
 sta FX,x
 lda HEIGHT,x
 clc
 adc VELOCITY,x
 bmi @bounce
 cmp #2
 bcc @bounce
 sta HEIGHT,x
 lda $8D
 and #1
 bne @hit
 dec VELOCITY,x
 jmp @hit
@bounce:
 lda #2
 sta HEIGHT,x
 lda #3
 sta VELOCITY,x
@hit:
 jsr FireHit
 jmp @sn
@kill:
 lda #0
 sta TTL,x
@sn:
 ldx SHOT
 inx
 cpx #4
 bne @shots
 jsr ConstrainHumanPositions
 jmp Prepare

ConstrainHumanPositions:
 ; D0C0 rejects an entire movement step if its starting depth lies
 ; outside A9..C7, so even walking toward the mat cannot recover. A pin
 ; aligns unequal native body heights and can leave the pinner below C7
 ; after a kick-out. Normalize free human bodies after native updates.
 ; Active pins and the original rope/climbing scripts retain ownership
 ; of their temporary coordinates until those states release the body.
 ldx #0
@actor:
 lda $012D,x
 cmp #$FF
 beq @next
 lda PIN_ACTIVE,x
 ora $CB,x
 ora $C0,x
 bne @next
 jsr ConstrainRing
@next:
 inx
 cpx #2
 bne @actor
 rts

ConstrainRing:
 lda $2E,x
 cmp #$A9
 bcs :+
 lda #$A9
:
 cmp #$C8
 bcc :+
 lda #$C7
:
 sta $2E,x
 ; Restore the perspective-dependent side boundaries as well. A body
 ; brought back from outside a corner must be free to move on both axes.
 sec
 sbc #$A8
 sta TMP
 lda #$33
 sec
 sbc TMP
 cmp $2C,x
 bcc @right
 beq @right
 clc
 adc #1
 sta $2C,x
@right:
 lda #$B8
 clc
 adc TMP
 sta TMP
 lda $2C,x
 cmp TMP
 bcc @done
 lda TMP
 sec
 sbc #1
 sta $2C,x
@done:
 rts

Spawn:
 lda COOL,x
 bne @done
 lda $CB,x
 ora $A2,x
 ora PIN_ACTIVE,x
 bne @done
 lda $78
 cmp #$3F
 bcc @done
 txa
 asl
 tay
 lda TTL,y
 beq @slot
 iny
 lda TTL,y
 bne @done
@slot:
 lda #16
 sta COOL,x
 lda #60
 sta TTL,y
 txa
 sta OWNER,y
 lda $2C,x
 clc
 adc $36,x
 clc
 adc #4
 sta FX,y
 lda $2E,x
 clc
 adc $38,x
 sec
 sbc $42,x
 clc
 adc $30,x
 sta FY,y
 lda #16
 sta HEIGHT,y
 lda #1
 sta VELOCITY,y
 lda $3A,x
 and #1
 eor #1
 sta DIR,y
@done:
 rts
FireHit:
 lda OWNER,x
 eor #1
 tay
 lda HITWAIT,y
 beq :+
 rts
:
 lda $CB,y
 ora $A4,y
 ora $A2,y
 ora $C0,y
 beq :+
 rts
:
 lda $2C,y
 clc
 adc $36,y
 sec
 sbc FX,x
 clc
 adc #9
 cmp #27
 bcc :+
 rts
:
 lda $2E,y
 clc
 adc $38,y
 sec
 sbc $42,y
 clc
 adc $30,y
 sta TMP
 lda FY,x
 sec
 sbc HEIGHT,x
 sec
 sbc TMP
 clc
 adc #32
 cmp #34
 bcs @done
 lda #0
 sta TTL,x
 lda #18
 sta HITWAIT,y
 ; Actor positions/states use the defender slot Y. Native energy bars
 ; are stored in the opposite order: actor 1 owns $79, actor 0 $7A.
 ; The projectile owner's slot therefore indexes its defender's energy.
 lda OWNER,x
 tax
 lda $79,x
 sec
 sbc #14
 bcc @defeated
 beq @defeated
 sta $79,x
 sta TMP
 jmp @reaction
@defeated:
 ; Match native CE2A/CE97 immediately. The next frame's E220 HUD pass
 ; clamps underflow before CF01 can see a late custom projectile hit.
 lda #0
 sta $79,x
 sta TMP
 lda #$FF
 sta $A2,y
 lda $B7,y
 sec
 sbc #1
 sta $B7,y
@reaction:
 lda #0
 sta $40,y
 sta $3E,y
 ; Native hit reactions change the action, not the current CHR pose.
 ; The three-phase streamer must finish the old pose before switching.
 tya
 eor #1
 tax
 lda $2A,x
 tax
 lda HurtAction,x
 sta $3C,y
 lda TMP
 cmp #28
 bcs @done
 lda DownAction,x
 sta $3C,y
@done:
 rts
Cols:.byte 0,8,16,0,8,16,0,8,16,0,8,16
Rows:.byte 0,0,0,8,8,8,16,16,16,24,24,24
CacheLow:.byte 0,48
NativeChrBase:.byte $EB,$C3,$D7,$EB,$C3,$D7
StreamLo:
 .repeat POSE_COUNT,P
 .byte <(StreamData+P*224)
 .endrepeat
StreamHi:
 .repeat POSE_COUNT,P
 .byte >(StreamData+P*224)
 .endrepeat
StreamCopy:
 ldy #0
 ; Only 14 of the native packet's 20 tiles are needed. An unrolled
 ; indirect copy fits one code bank and runs outside the HUD split.
 .repeat 224,I
 lda ($17),y
 sta $0200+I
 .if I<223
 iny
 .endif
 .endrepeat
 rts
StreamData:.incbin "../build/streamed-poses.chr"
HurtAction:.incbin "../build/hurt.bin"
HurtBack:.incbin "../build/hurt-back.bin"
DownAction:.incbin "../build/down.bin"
PinAction:.incbin "../build/pin-action.bin"
PinHold:.incbin "../build/pin-hold.bin"
; Side movement, direct melee and native hurt/throw scripts per character.
Actions:
.byte 0,0,0,0,0,8,10,10,8,8,10,10,8,5,6,6,8,4,8,8,8,8,8,8,8,8,8,8,8,8,8,8
.byte 0,0,0,0,0,8,5,6,6,8,8,4,10,10,8,8,10,8,8,8,10,8,8,8,8,8,8,8,8,8,8,8
.align $100
PoseMap:.incbin "../build/pose-map.bin"
.align $100
PoseAttrs:.incbin "../build/pose-attrs.bin"
.align $100
PortraitData:.incbin "../build/portrait.chr"
NativePortraits:.incbin "../build/native-portraits.bin"
.align $100
NativeStats:.incbin "../build/native-stats.bin"
NativeNames:.incbin "../build/native-names.bin"
MarioNames:.word MarioName,LuigiName
MarioName:.byte 13,"MARIO",0
LuigiName:.byte 13,"LUIGI",0
.align $100
MarioStats:
.incbin "../build/mario-stats.bin"

.segment "PATTERNCOPY"
PatternCopy:
 lda $27
 cmp #$FF
 bne @copy
 lda $28
 cmp #$AB
 bne @copy
 lda $71
 and #1
 eor #1
 tay
 lda $012D,y
 cmp #$FF
 bne @human
@copy:
 ldy #0
 .repeat 16,I
 lda ($21),y
 sta ($25),y
 .if I<15
 iny
 .endif
 .endrepeat
@human:
 rts

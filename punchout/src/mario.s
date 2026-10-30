.setcpu "6502"
.macpack longbranch
.export ResetMario, RenderMario, PrepareMario, MarioVblank, FireCombat, PaletteRead, PaletteUpload
.export FireUpdate, FireHit, ShadowFrame
.export PortraitEntry, PortraitDraw
.export OptionalVram
.export FightInit
; Private MMC2 work RAM, declared in the NES 2.0 header. Native CPU RAM is untouched.
ACTIVE=$6000
LASTB=$6001
COOLDOWN=$6002
AGE=$6010
FX=$6012
FY=$6014
FTYPE=$6016
OLDLO=$6018
OLDHI=$601A
PREVPTR=$6020
NEXTFRAME=$6022
SLOT=$6023
HITS=$6024
SPAWNS=$6025
SCRATCH=$6026
RENDERPTR=$6028
SHADOW=$6400

.segment "BOOT"
ResetMario:
 jsr ClearState
 jmp $a1c4
FightInit:
 txa
 pha
 tya
 pha
 lda HITS
 pha
 lda SPAWNS
 pha
 jsr ClearState
 pla
 sta SPAWNS
 pla
 sta HITS
 pla
 tay
 pla
 tax
 jmp $aa1d
ClearState:
 lda #0
 ldx #$3f
@clear: sta $6000,x
 dex
 bpl @clear
 lda #$fe
 ldx #0
@shadow: sta SHADOW,x
 sta SHADOW+$100,x
 sta SHADOW+$200,x
 sta SHADOW+$300,x
 inx
 bne @shadow
 rts

.segment "FIXED"
RenderMario:
 lda $61
 jmi @native
 cmp #98
 jcs @native
 lda $0d
 pha
 lda #6
 jsr $aa4a
 lda $61
 asl
 tay
 lda $8011,y
 sta $e2
 lda $8012,y
 sta $e3
 cmp RENDERPTR+1
 bne @changed
 lda $e2
 cmp RENDERPTR
 beq @done
@changed:
 lda RENDERPTR+1
 beq @new
 sta $e1
 lda RENDERPTR
 sta $e0
 ldy #0
@erasecol:
 lda ($e0),y
 beq @new
 sta $2006
 iny
 lda ($e0),y
 sta $2006
 iny
 lda ($e0),y
 tax
 iny
 lda #$fe
@erase:
 sta $2007
 iny
 dex
 bne @erase
 jmp @erasecol
@new:
 lda $e2
 sta $e0
 sta RENDERPTR
 lda $e3
 sta $e1
 sta RENDERPTR+1
 ldy #0
@column:
 lda ($e0),y
 beq @done
 sta $2006
 iny
 lda ($e0),y
 sta $2006
 iny
 lda ($e0),y
 tax
 iny
@tile:
 lda ($e0),y
 sta $2007
 iny
 dex
 bne @tile
 bne @column
 jmp @column
@done:
 lda #0
 sta $60
 lda #2
 sta $69
 pla
 jsr $aa4a
 rts
@native:
 jsr $8020
 lda #2
 sta $69
 rts

PrepareMario:
 jsr $8280
 lda $61
 bmi @done
 cmp #98
 bcs @done
 lda $60
 cmp #1
 bne @done
 lda $0d
 pha
 lda #6
 jsr $aa4a
 jsr ShadowFrame
 pla
 jsr $aa4a
@done: rts

MarioVblank:
 ; The portrait uses its own copy of the FD atlas; the ring/referee use CHR0.
 lda #0
 sta $d000
 ; Restore the background beneath the last displayed fireballs before Mac uploads.
 ldx #1
@clear:
 lda OLDHI,x
 beq @next
 sta $e1
 lda OLDLO,x
 sta $e0
 jsr RestoreFireColumn
 inc $e0
 bne :+
 inc $e1
:
 jsr RestoreFireColumn
 lda #0
 sta OLDHI,x
@next:
 dex
 bpl @clear
 lda $60
 beq @balls
 bmi @balls
 jsr $aa9f
 lda $69
 sta $e000
 dec $1a
@balls:
 lda $69
 cmp #2
 bne @exit
 lda $1c
 bne @exit
 lda $04
 cmp #$ff
 bne @exit
 ldx #1
@ball:
 lda AGE,x
 beq @ballnext
 ; Floor scroll differs from the static HUD. Convert screen X back to ring space.
 lda FX,x
 sec
 sbc #8
 clc
 adc $15
 lsr
 lsr
 lsr
 sta $e0
 lda AGE,x
 sec
 sbc #2
 and #15
 tay
 lda FY,x
 sec
 sbc Bounce,y
 sec
 sbc #8
 cmp #96
 bcs :+
 lda #96
:
 sta $e4
 and #$f8
 asl
 rol a
 rol a
 and #3
 clc
 adc #$20
 sta $e1
 lda $e4
 and #$38
 asl
 asl
 ora $e0
 sta $e0
 sta OLDLO,x
 lda $e1
 sta OLDHI,x
 lda AGE,x
 lsr
 lsr
 and #3
 asl
 asl
 tay
 jsr DrawFireColumn
 inc $e0
 bne :+
 inc $e1
:
 jsr DrawFireColumn
@ballnext:
 dex
 bpl @ball
@exit: jmp $a5ec

RestoreFireColumn:
 lda $e1
 sta $2006
 clc
 adc #$44
 sta $e3
 lda $e0
 sta $2006
 sta $e2
 ldy #0
 lda ($e2),y
 sta $2007
 ldy #32
 lda ($e2),y
 sta $2007
 rts
DrawFireColumn:
 lda $e1
 sta $2006
 lda $e0
 sta $2006
 lda FireTiles,y
 sta $2007
 iny
 lda FireTiles,y
 sta $2007
 iny
 rts

OptionalVram:
 ; Palette/queued HUD transfers each consume one of the native two vblank jobs.
 ; Defer a pending HUD job instead of running it after the budget reaches zero.
 lda $1a
 beq @done
 lda $0410
 bpl @hud
 ldx $10
 stx $2000
 jsr $c24a
 dec $1a
 beq @done
@hud: jmp $a613
@done: jmp $a63e

PaletteRead:
 lda $0480,y
 ; Preserve the native palette buffer, hit/exhaustion state and fade deadlines.
 cpy #$0d
 bcc @done
 cpy #$10
 bcs @done
 ldx $04
 inx
 bne @done
 lda $048d
 bmi @black
 and #$30
 sta SCRATCH
 cpy #$0d
 beq @white
 cpy #$0e
 beq @red
 lda SCRATCH
 ora #7
 rts
@white: lda SCRATCH
 ora #$00
 rts
@red:
 lda SCRATCH
 cmp #$20
 bcs @fullred
 cmp #$10
 bcc @black
 lda #6
 rts
@fullred: lda #$16
@done: rts
@black: lda #$0f
 rts

PaletteUpload:
 ldx #$3f
 ldy #0
 jsr $af2e
@first:
 lda $0480,y
 sta $2007
 iny
 cpy #$0d
 bne @first
@mario:
 lda $04
 cmp #$ff
 bne @nativeMario
 lda $048d
 bmi @black
 and #$30
 tax
 sta $2007
 cmp #$20
 bcs @red
 cmp #$10
 bcs @darkred
 lda #$0f
 bne @redout
@darkred: lda #6
 bne @redout
@red: lda #$16
@redout:
 sta $2007
 txa
 ora #7
 sta $2007
 bne @tail
@black:
 lda #$0f
 sta $2007
 sta $2007
 sta $2007
 bne @tail
@nativeMario:
 lda $048d
 sta $2007
 lda $048e
 sta $2007
 lda $048f
 sta $2007
@tail:
 ldy #$10
@last:
 lda $0480,y
 sta $2007
 iny
 cpy #$20
 bne @last
 jmp $af1d

FireCombat:
 jsr $8015
 jmp FireUpdate
PortraitEntry:
 lda $0d
 pha
 lda #9
 jsr $aa4a
 jsr PortraitDraw
 pla
 jsr $aa4a
 lda #$ff
 sta $1d
 jmp $a86b
.include "generated.inc"

.segment "PORTRAIT"
PortraitDraw:
 lda #3
 sta $d000
 lda $10
 and #$fb
 sta $2000
 lda #$22
 sta $e1
 lda #6
 sta $e0
 ldy #0
@row:
 lda $2002
 lda $e1
 sta $2006
 lda $e0
 sta $2006
 ldx #6
@tile:
 lda PortraitTiles,y
 sta $2007
 iny
 dex
 bne @tile
 lda $e0
 clc
 adc #32
 sta $e0
 bcc @same
 inc $e1
@same:
 cpy #48
 bne @row
 ; Set palette 2 for just the right half of the left portrait (Doc stays native).
 lda #$e1
 jsr PortraitAttr
 lda #$e9
 jsr PortraitAttr
 lda #$23
 sta $2006
 lda #$e2
 sta $2006
 lda #$aa
 sta $2007
 lda #$23
 sta $2006
 lda #$ea
 sta $2006
 lda #$aa
 sta $2007
 lda #$30
 sta $048a
 lda #$16
 sta $048b
 lda #$80
 sta $04a0
 lda $10
 sta $2000
 rts
PortraitAttr:
 sta $e0
 lda #$23
 sta $2006
 lda $e0
 sta $2006
 lda $2007
 lda $2007
 and #$33
 ora #$88
 pha
 lda #$23
 sta $2006
 lda $e0
 sta $2006
 pla
 sta $2007
 rts
.include "portrait.inc"

.segment "SHADOW"
; Called after native pose preparation in the visible part of the frame, never in vblank.
; A private tile shadow restores fireballs without erasing Mario's fists/body.
ShadowFrame:
 lda $61
 asl
 tay
 lda $8011,y
 sta NEXTFRAME
 lda $8012,y
 sta NEXTFRAME+1
 cmp PREVPTR+1
 bne @update
 lda NEXTFRAME
 cmp PREVPTR
 beq @done
@update:
 lda PREVPTR+1
 beq @new
 sta $e1
 lda PREVPTR
 sta $e0
 lda #0
 sta $e5
 jsr ShadowCopy
@new:
 lda NEXTFRAME
 sta $e0
 sta PREVPTR
 lda NEXTFRAME+1
 sta $e1
 sta PREVPTR+1
 lda #1
 sta $e5
 jsr ShadowCopy
@done: rts
ShadowCopy:
 ldy #0
@column:
 lda ($e0),y
 beq @done
 clc
 adc #$44
 sta $e3
 iny
 lda ($e0),y
 sta $e2
 iny
 lda ($e0),y
 sta $e4
 iny
@tile:
 lda ($e0),y
 ldx $e5
 bne @write
 lda #$fe
@write:
 sty $e6
 ldy #0
 sta ($e2),y
 ldy $e6
 iny
 lda $e2
 clc
 adc #32
 sta $e2
 bcc @same
 inc $e3
@same:
 dec $e4
 bne @tile
 jmp @column
@done: rts

.segment "FIRE"
FireUpdate:
 lda $04
 cmp #$ff
 jne ClearFire
 lda $1c
 jne ClearFire
 lda $05
 jne ClearFire
 lda $50
 and #$7f
 jeq ClearFire
 cmp #$40
 jcs ClearFire
 lda $0392
 jeq ClearFire
 lda $0399
 jeq ClearFire
 lda $bb
 jmi ClearFire
 lda COOLDOWN
 beq @input
 dec COOLDOWN
@input:
 lda $d0
 and #$40
 beq @released
 ldy LASTB
 bne @held
 sta LASTB
 lda COOLDOWN
 bne @held
 lda $bc
 beq @held
 ldx #0
 lda AGE
 beq @spawn
 inx
 lda AGE+1
 bne @held
@spawn:
 lda #1
 sta AGE,x
 inc SPAWNS
 lda #16
 sta COOLDOWN
 ldy $61
 cpy #98
 bcc @anchor
 ldy #0
@anchor:
 lda LaunchX,y
 sec
 sbc $15
 sta FX,x
 lda LaunchY,y
 sta FY,x
 lda $d0
 and #8
 beq @gut
 lda #1
 bne @type
@gut: lda #3
@type: sta FTYPE,x
 bne @held
@released:
 sta LASTB
@held:
 jmp MoveFire
ClearFire:
 lda #0
 sta AGE
 sta AGE+1
 sta COOLDOWN
 sta LASTB
 rts

MoveFire:
 ldx #1
@loop:
 lda AGE,x
 beq @next
 inc AGE,x
 lda AGE,x
 cmp #80
 bcs @kill
 cmp #3
 bcc @next
 lda FY,x
 sec
 sbc #2
 sta FY,x
 cmp #96
 bcc @kill
 ; Projectiles aim at native head/body openings, rather than bypassing defense.
 lda FTYPE,x
 cmp #1
 bne @body
 lda $b1
 sec
 sbc #72
 cmp #104
 bcs @target
 lda #104
 bne @target
@body:
 lda $b1
 sec
 sbc #32
 cmp #120
 bcs @target
 lda #120
@target:
 cmp FY,x
 bcc @next
 lda FX,x
 sec
 sbc $b0
 clc
 adc #24
 cmp #49
 bcs @kill
 stx SLOT
 jsr FireHit
 ldx SLOT
@kill:
 lda #0
 sta AGE,x
@next:
 dex
 bpl @loop
 rts

FireHit:
 lda FTYPE,x
 tay
 lda $b6,y
 cmp #4
 bcc @open
 rts
@open:
 ; Run the exact native normal-punch resolution (block, invulnerability, stars,
 ; special knockdowns, score, referee count). No direct HP writes.
 lda $74
 pha
 lda $75
 pha
 lda $76
 pha
 lda $77
 pha
 lda $58
 pha
 lda $51
 pha
 lda $b5
 pha
 lda #0
 sta $b5
 sta $76
 sta $77
 lda FTYPE,x
 sta $74
 lda #4
 sta $75
 lda #$80
 sta $58
 ldy #0
 jsr $81b2
 lda $58
 cmp #3
 beq @hit
 pla
 sta $b5
 jmp @restore
@hit:
 inc HITS
 pla
@restore:
 pla
 sta $51
 pla
 sta $58
 pla
 sta $77
 pla
 sta $76
 pla
 sta $75
 pla
 sta $74
 lda $05
 cmp #1
 bne @done
 ; An asynchronous projectile can finish after the body punch has ended.
 ; Hand Mac to the native opponent-down script, just as a punch completion does.
 lda #$c1
 sta $50
@done:
 rts

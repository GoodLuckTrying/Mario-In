.setcpu "6502"
.macpack longbranch
.export Boot,Init,PlayerGate,DrawGate,GravityGate,JumpGate,DamageGate,StompGate,DmaGate,RespawnGate
.export DrawMario,PowerStep
.export SceneGate,FireUpdate,FireDraw,ProjectShot,SpawnShot
.export FireHit
.export InputGate,ReadFireButtons
.export EatGate,ManholeLookup
.export SetupAtlas,DrawStart,DisplayBank,DrawScene
.export NativeActorGate,ShadowGate
.export LoadSprite,LoadBackground,StageDirections,SelectDirection,CommitDirections
.export StreamNmi,RawChr0,RawChr1
.export CopyNmi
S_POWER=$7000
S_WEIGHT=$7002
S_COUNT=$7004
S_DIR=$7006
S_READY=$7008
S_LIVES=$700A
S_ACTOR=$7010
S_OAM=$7011
S_X=$7012
S_Y=$7013
S_TILE=$7014
S_ATTR=$7015
S_ROW=$7016
S_TEMP=$7017
S_VISIBLE=$7018
S_SAVEA=$7019
S_BASETILE=$701A
S_BASEY=$701B
S_ROWS=$701C
S_LAYER=$701D
S_LASTDIR=$7020
S_SHOT=$7022
S_OWNER=$7023
S_TARGET=$7024
S_FX=$7040
S_FXH=$7044
S_FY=$7048
S_FYH=$704C
S_FZ=$7050
S_FZH=$7054
S_FL=$7058
S_FDX=$705C
S_FDY=$7060
S_FSX=$7064
S_FSY=$7068
S_FGROUND=$706C
S_FV=$7070
S_FVF=$7074
S_FP=$7078
S_FCOUNT=$707C
S_FGH=$7080
S_FIREEDGE=$7088
S_HELDB=$708D
S_RAWB=$708F
S_GROUP=$7090
S_VARIANT=$7091
S_FIREPOSE=$7092
S_FRAMEBANK=$7093
S_ATLASREADY=$7094
S_CELLATTR=$7095
S_PTR=$7096
S_SELECTED=$7098
S_CACHEDVAR=$7099

S_ACTIVE=$70A0
S_AID=$70A2
S_APOWER=$70A4
S_ADIR=$70A6
S_PID=$70A8
S_PPOWER=$70AA
S_PDIR=$70AC
S_WID=$70AE
S_WPOWER=$70B0
S_WDIR=$70B2
S_STREAM=$70B4
S_NATIVE_SPR=$70B5
S_NATIVE_BG=$70B6
S_BANK=$70B7
S_LOAD=$70B8
S_COPY=$70B9
S_OAMSTART=$70BA
S_DRAWN=$70BC
S_CACHEMODE=$70BE
S_DESTHI=$70BF
S_BITS=$70C0
S_INDEX=$70C1
S_COMMIT=$70C2
S_SP0=$70C3
S_SP1=$70C4
S_AUDIOBANK=$70C5
S_CHUNKINDEX=$70C6
S_DMAPAGE=$70C7
S_COMMITREADY=$70C8
S_PREPARING=$70C9
S_CHUNKCACHE=$70D8 ; eight equality IDs per physical bank
S_PENDINGCHUNKS=$70E8 ; four interleaved pairs

.segment "BOOT"
Boot:
 cld
 ldx #$E8
 txs
 jsr $8242
 lda #$12
 jsr $FFB5
 lda #2
 sta $EFFF
 lsr
 sta $EFFF
 lsr
 sta $EFFF
 lsr
 sta $EFFF
 lsr
 sta $EFFF
 ldy #0
 sty $08
 lda #$90
 sta $09
 sty $0A
 lda #$60
 sta $0B
 ldx #16
@copy:
 lda ($08),y
 sta ($0A),y
 iny
 bne @copy
 inc $09
 inc $0B
 dex
 bne @copy
 jmp Init
.segment "CODE"
Init:
 lda #0
 jsr PrgBank
 lda #0
 ldx #0
@clear: sta $7000,x
 inx
 bne @clear
 ; Original CHR also stores executable room/music data. Populate all
 ; eight native banks once; native bank numbers and PPU reads stay exact.
 lda #0
 sta S_BANK
@nativeBanks:
 lda S_BANK
 jsr RawChr0
 lda S_BANK
 ldx #0
 jsr LoadNative
 inc S_BANK
 lda S_BANK
 cmp #8
 bcc @nativeBanks
 lda #0
 jsr RawChr0
 jsr $F51D
 jsr $C3B7
 jsr $02C7
 ldx #$30
 jsr $C3D7
 jsr $8460
 ldy #$36
 jsr $0200
 lda #$68
 sta $4C
 jmp $85C2
PrgBank:
 sta $EFFF
 lsr
 sta $EFFF
 lsr
 sta $EFFF
 lsr
 sta $EFFF
 lsr
 sta $EFFF
 rts
RawChr0:
 sta $BFFF
 lsr
 sta $BFFF
 lsr
 sta $BFFF
 lsr
 sta $BFFF
 lsr
 sta $BFFF
 rts
RawChr1:
 sta $DFFF
 lsr
 sta $DFFF
 lsr
 sta $DFFF
 lsr
 sta $DFFF
 lsr
 sta $DFFF
 rts
LoadSprite:
 jmp RawChr0
LoadBackground:
 jmp RawChr1
LoadNative:
 ; Native CHR-ROM bank switches become forced-blank CHR-RAM loads.
 ; This runs only when a native bank changes, never during steady play.
 sta S_LOAD
 stx S_COPY
 txa
 pha
 tya
 pha
 lda $08
 pha
 lda $09
 pha
 lda $00
 and #$7F
 sta $2000
 lda #0
 sta $2001
 lda S_COPY
 beq @sprite
 lda S_LOAD
 jsr RawChr1
 jmp @bank
@sprite:
 ; The caller has already selected the destination physical sprite bank.
@bank:
 lda #4
 jsr PrgBank
 lda S_LOAD
 asl
 asl
 asl
 asl
 ora #$80
 sta $09
 lda #0
 sta $08
 bit $2002
 lda S_COPY
 sta $2006
 lda #0
 sta $2006
 ldx #16
 ldy #0
@page:
 lda ($08),y
 sta $2007
 iny
 bne @page
 inc $09
 dex
 bne @page
 lda #0
 jsr PrgBank
 pla
 sta $09
 pla
 sta $08
 pla
 tay
 pla
 tax
 lda #0
 rts
SetupAtlas:
 sta $E2
 ; Every scene starts with exact native NPC graphics in both sprite banks.
 lda #8
 sta S_ACTIVE
 jsr RawChr0
 lda $E2
 sta S_SP0
 sta S_SP1
 sta S_NATIVE_SPR
 ldx #0
 jsr LoadNative
 lda #10
 jsr RawChr0
 lda $E2
 ldx #0
 jsr LoadNative
 lda #0
 sta S_STREAM
 sta S_DRAWN
 sta S_DRAWN+1
 ldx #1
@defaults:
 lda #10
 sta S_WID,x
 sta S_AID,x
 lda #0
 sta S_WPOWER,x
 sta S_APOWER,x
 lda #64
 sta S_WDIR,x
 sta S_ADIR,x
 dex
 bpl @defaults
 lda #2
 sta S_ATLASREADY
 ldx #$0F
 ldy #$8C
 jmp $8458
InitializeDirections:
 lda $00
 and #$7F
 sta $2000
 lda #0
 sta $2001
 jsr CopyDirections
 lda #2
 jsr PrgBank
 lda #8
 jsr RawChr0
 jsr UploadAll
 lda #10
 jsr RawChr0
 jsr UploadAll
 lda #0
 jsr PrgBank
 lda #8
 sta S_ACTIVE
 jsr RawChr0
 ldx #7
@cache:
 ldy PendingIndex,x
 lda S_PENDINGCHUNKS,y
 sta S_CHUNKCACHE,x
 sta S_CHUNKCACHE+8,x
 dex
 bpl @cache
 lda #1
 sta S_ATLASREADY
 rts
UploadAll:
 jsr UploadChunk0
 jsr UploadChunk1
 jsr UploadChunk2
 jsr UploadChunk3
 jsr UploadChunk4
 jsr UploadChunk5
 jsr UploadChunk6
 jsr UploadChunk7
 bit $2002
 lda #<((FireSlot)*16)
 ldy #>((FireSlot)*16)
 sty $2006
 sta $2006
 ldy #0
@fire:
 lda FirePattern,y
 sta $2007
 iny
 cpy #16
 bne @fire
 rts
DisplayBank:
 lda S_ACTIVE
 jmp RawChr0
DrawScene:
 jsr DrawStart
 jsr $FA31
 php
 pha
 txa
 pha
 tya
 pha
 jsr PrepareCommitOam
 pla
 tay
 pla
 tax
 pla
 plp
 rts
NativeActorGate:
 lda $049B,y
 cmp #5
 beq @tail
 tay
 jmp $FAFC
@tail:
 jmp $FBAC
ShadowGate:
 lda $049B,y
 beq @tail
 cmp #5
 beq @tail
 cmp #$25
 jmp $FBC0
@tail:
 jmp $FC16
DrawStart:
 lda S_ATLASREADY
 cmp #2
 bne :+
 jsr InitializeDirections
:
 lda #0
 sta S_DRAWN
 sta S_DRAWN+1
 ; Mirroring changes OAM only. Apply it immediately, including while a
 ; pose upload is pending, rather than making turns wait for CHR data.
 ldx #1
@facing:
 lda S_LASTDIR,x
 and #15
 tay
 lda DirectionFlip,y
 sta S_ADIR,x
 sta S_PDIR,x
 dex
 bpl @facing
 lda S_ATLASREADY
 beq @done
 jsr SkipResidentChunks
 lda S_STREAM
 bne @done
 jsr StageDirections
@done:
 rts
SelectDirection:
 lda S_POWER,x
 sta S_WPOWER,x
 asl
 asl
 clc
 adc S_POWER,x
 sta S_INDEX
 asl
 asl
 clc
 adc S_INDEX
 sta S_INDEX
 lda S_LASTDIR,x
 and #15
 tay
 lda DirectionView,y
 clc
 adc S_INDEX
 sta S_WID,x
 lda DirectionFlip,y
 sta S_WDIR,x
 lda $05C7,x
 cmp #$FF
 beq @ground
 lda #4
 bne @pose
@ground:
 lda $16,x
 and #15
 beq @pose
 lda $03
 lsr
 lsr
 lsr
 and #3
 tay
 lda WalkPose,y
@pose:
 clc
 adc S_WID,x
 sta S_WID,x
 rts
StageDirections:
 ldx #1
@select:
 jsr SelectDirection
 dex
 bpl @select
 lda S_WID
 cmp S_AID
 bne @start
 lda S_WID+1
 cmp S_AID+1
 bne @start
 lda S_WDIR
 cmp S_ADIR
 bne @start
 lda S_WDIR+1
 cmp S_ADIR+1
 beq @done
@start:
 lda #0
 sta S_COMMITREADY
 jsr CopyDirections
 lda #1
 sta S_STREAM
 jsr SkipResidentChunks
@done:
 rts
CopyDirections:
 ; Mask only the serial mapper write. The asset bank has a bank-safe
 ; lag-NMI vector, so copying a pose never delays vblank by 50 scanlines.
 lda $00
 and #$7F
 sta $2000
 ldx #1
@chunks:
 ldy S_WID,x
 lda FrameChunk0,y
 sta S_PENDINGCHUNKS,x
 lda FrameChunk1,y
 sta S_PENDINGCHUNKS+2,x
 lda FrameChunk2,y
 sta S_PENDINGCHUNKS+4,x
 lda FrameChunk3,y
 sta S_PENDINGCHUNKS+6,x
 dex
 bpl @chunks
 lda #6
 jsr PrgBank
 lda S_ATLASREADY
 cmp #1
 bne :+
 lda $00
 ora #$80
 sta $2000
:
 ldx #0
@actor:
 lda S_WID,x
 cmp S_PID,x
 bne @copyActor
 lda S_ATLASREADY
 cmp #1
 beq @next
@copyActor:
 lda S_WID,x
 sta S_PID,x
 clc
 adc #$80
 sta $09
 lda #0
 sta $08
 lda S_WPOWER,x
 sta S_PPOWER,x
 lda S_WDIR,x
 sta S_PDIR,x
 cpx #0
 bne @second
 jsr CopyFrame0
 jmp @next
@second:
 jsr CopyFrame1
@next:
 inx
 cpx #2
 bne @actor
 lda $00
 and #$7F
 sta $2000
 lda #0
 jsr PrgBank
 lda S_ATLASREADY
 cmp #1
 bne @done
 lda $00
 ora #$80
 sta $2000
@done:
 rts
CopyNmi:
 ; Native lag-NMI behavior, with both mapper selection and interrupted
 ; registers restored before returning to the in-progress frame copy.
 sta $49
 lda $2002
 stx $4A
 sty $4B
 lda #0
 jsr PrgBank
 jsr $AC3E
 lda #$80
 sta $A4
 jsr $D54A
 jsr $8BE1
 jsr DisplayBank
 jsr $D69A
 lda #6
 jsr PrgBank
 ldx $4A
 ldy $4B
 lda $49
 rti
; Native input is isometric: Right travels down/right, Down down/left,
; Left up/left, and Up up/right. Diagonal inputs project to screen axes.
DirectionView: .byte 10,5,15,10,5,0,10,0,15,10,20,20,10,10,10,10
; The supplied sheet's canonical side/diagonal cells face LEFT.
; Mirror those cells for rightward movement; front/back need no mirror.
DirectionFlip: .byte 64,64,0,0,0,0,0,0,64,64,0,0,0,0,0,0
WalkPose: .byte 1,2,3,2
PlayerGate:
 cpx #2
 bcs @native
 jsr PowerStep
@native:
 lda $0577,x
 jmp $96FB
InputGate:
 jsr $D279
ReadFireButtons:
 ; Capture both physical controllers before native animation/AI can skip
 ; an actor update or rewrite its controls. Native held/fresh B bytes
 ; remain intact for tongue attacks and eating.
 ldx #1
@pad:
 lda $16,x
 and #$40
 sta S_RAWB
 eor S_HELDB,x
 and S_RAWB
 sta S_FIREEDGE,x
 lda S_RAWB
 sta S_HELDB,x
 dex
 bpl @pad
 rts
PowerStep:
 stx S_ACTOR
 lda S_READY,x
 bne @life
 inc S_READY,x
 lda $059F,x
 and #$3F
 sta S_WEIGHT,x
 lda $03DF,x
 sta S_LIVES,x
 lda #1
 sta S_DIR,x
@life:
 lda $03DF,x
 cmp S_LIVES,x
 beq :+
 bcs @storeLife
 ; Only an actual life loss resets the form. A 1-Up never shrinks Mario.
 lda #0
 sta S_POWER,x
 sta S_COUNT,x
 lda $03DF,x
@storeLife:
 sta S_LIVES,x
:
@direction:
 lda $16,x
 and #$0F
 beq :+
 sta S_LASTDIR,x
:
 lda $16,x
 and #3
 beq :+
 sta S_DIR,x
:
 rts
EatGate:
 ; Count completed native meals, independently of food color, tail
 ; allocation, maximum weight, room transitions, or extra lives.
 jsr $9D54
 cpx #2
 bcs @done
 lda S_POWER,x
 cmp #2
 bcs @done
 inc S_COUNT,x
 lda S_COUNT,x
 cmp #2
 bcc @done
 lda #0
 sta S_COUNT,x
 inc S_POWER,x
 lda #$38
 jsr $81F2
@done:
 rts
ManholeLookup:
 ; The original loop searches indefinitely when the collision metatile
 ; has no matching entry. Its real table is exactly 24 pairs at $01B0.
 ldy #0
@entry:
 lda $04D7,x
 and #$F0
 ora $04C3,x
 eor $01B0,y
 bne @next
 lda $01B1,y
 eor $04FF,x
 and #$F0
 bne @next
 jmp $CCF2
@next:
 iny
 iny
 cpy #$30
 bcc @entry
 ; Abort C476 before it spawns anything; discard its lookup JSR.
 pla
 pla
 jmp $C54F
JumpGate:
 cpx #2
 bcs :+
 lda #4
:
 jmp $9586
StompGate:
 lda #3
 jmp $9586
GravityGate:
 cpx #2
 bcs @native
 ldy $AA
 cpy #10
 beq @native
 ldy $C5
 bne @native
 ldy $BD
 bne @native
 ldy $05C7,x
 bmi @fall
 beq @fall
 lda $16,x
 and #$80
 beq @fall
 lda #$E0
 bne @native
@fall: lda #$90
@native:
 sta $04
 ldy $049B,x
 jmp $DF5A
DamageGate:
 ldx $0B
 cpx #2
 bcs @native
 lda S_POWER,x
 beq @small
 lda #0
 sta S_POWER,x
 sta S_COUNT,x
 lda #120
 sta $040D,x
 lda #1
 rts
@small:
 lda $059F,x
 and #$40
 ora #1
 sta $059F,x
@native:
 lda $059F,x
 jmp $BD7C
RespawnGate:
 pha
 lda #0
 sta S_POWER,x
 sta S_READY,x
 sta S_COUNT,x
 pla
 jmp $BE06
DrawGate:
 cpy #2
 bcc DrawMario
 lda $049B,y
 cmp #5
 beq @tail
 lda $04AF,y
 jmp $FE63
@tail: rts
DrawMario:
 sty S_ACTOR
 stx S_OAM
 cpx #$C0
 jcs @return
 txa
 sta S_OAMSTART,y
 lda #1
 sta S_DRAWN,y
 lda #2
 sta S_DESTHI
 lda S_APOWER,y
 sta S_SELECTED
 lda S_ADIR,y
 sta S_ATTR
 jsr RenderDirection
@return:
 ldy S_ACTOR
 rts
RenderDirection:
 lda S_OAM
 sta $0A
 lda S_DESTHI
 sta $0B
 ldy S_ACTOR
 lda $03B7,y
 sec
 sbc #8
 sta S_X
 lda $03CB,y
 sec
 sbc $0577,y
 sec
 sbc #25
 sta S_BASEY
 lda #0
 sta S_VISIBLE
 lda S_X
 cmp #248
 bcs @hide
 lda $040D,y
 beq @rows
 lda $02
 and #1
 beq @rows
@hide:
 inc S_VISIBLE
@rows:
 .repeat 4,I
 lda S_BASEY
 clc
 adc #I*8
 cmp #240
 bcs :+
 ldx S_VISIBLE
 bne :+
 .if I<2
 ldx S_SELECTED
 beq :+
 .endif
 jmp :++
:
 lda #$F8
:
 sta $70D0+I
 .endrepeat
 lda S_SELECTED
 cmp #2
 beq @fire
 lda S_ACTOR
 beq @clothes
 lda #3
 bne @clothes
@fire:
 lda #0
@clothes:
 ora S_ATTR
 sta S_CELLATTR
 lda S_ACTOR
 asl
 asl
 asl
 asl
 asl
 sta S_INDEX
 lda S_ATTR
 lsr
 lsr
 ora S_INDEX
 tax
 .repeat 16,I
 ldy #I*4
 lda $70D0+((I .mod 8)/2)
 sta ($0A),y
 iny
 lda SpriteOamSlots+I,x
 sta ($0A),y
 iny
 .if I<8
 lda S_CELLATTR
 .else
 lda S_ATTR
 ora #2
 .endif
 sta ($0A),y
 iny
 lda S_X
 .if I .mod 2
 clc
 adc #8
 .endif
 sta ($0A),y
 .endrepeat
 lda S_OAM
 clc
 adc #64
 tax
 rts
DmaGate:
 lda #2
 sta S_DMAPAGE
 lda S_ATLASREADY
 beq @dma
 jsr StreamNmi
 ; Shared exact Fire Mario shades, approved by the user.
 bit $2002
 lda #$3F
 sta $2006
 lda #$12
 sta $2006
 lda #$16
 sta $3B
 sta $2007
 lda #$37
 sta $3C
 sta $2007
 lda #$3F
 sta $2006
 lda #$1A
 sta $2006
 lda #$27
 sta $43
 sta $2007
 lda #$37
 sta $44
 sta $2007
@dma:
 lda S_DMAPAGE
 sta $4014
 rts
StreamNmi:
 lda S_PREPARING
 jne @done
 lda S_STREAM
 jeq @done
 ; Native intermission/menu scenes select their own font bank.
 lda $11
 cmp #$8C
 jne @done
 lda $10
 cmp #$69
 jne @done
 ; A4<0 means the native terrain queue is empty. Terrain updates and
 ; music command parsing have variable cost and own this vblank first.
 ; F9 temporarily reserves the PPU for a native data-bank read.
 lda $F9
 bne @done
 lda $A4
 bpl @done
 ldx #12
@music:
 lda $0301,x
 bpl @channel
 lda $0302,x
 cmp #1
 beq @done
@channel:
 dex
 dex
 dex
 dex
 bpl @music
 ; AE17 may animate four background cells before restoring scroll.
 ; Reserve this vblank when any native animation timer is due.
 ldx #3
@background:
 lda $042D,x
 beq @nextBackground
 clc
 adc #1
 cmp #2
 beq @done
 cmp $0461,x
 beq @done
@nextBackground:
 dex
 bpl @background
@available:
 lda S_STREAM
 beq @done
 cmp #9
 jeq CommitDirections
 ; Skip unchanged chunks without spending a frame on each. Equality
 ; IDs describe the actual target bank, not just the displayed pose.
 tax
 dex
 ldy PendingIndex,x
 lda S_PENDINGCHUNKS,y
 pha
 lda S_ACTIVE
 cmp #8
 bne :+
 txa
 ora #8
 tax
:
 stx S_CHUNKINDEX
 pla
 cmp S_CHUNKCACHE,x
 bne @transfer
 inc S_STREAM
 rts
@transfer:
 sta S_CHUNKCACHE,x
 lda #2
 jsr PrgBank
 lda S_ACTIVE
 eor #2
 jsr RawChr0
 jsr UploadStep
@uploaded:
 inc S_STREAM
 lda S_ACTIVE
 jsr RawChr0
 lda #0
 jsr PrgBank
@done:
 rts
PendingIndex: .byte 0,2,4,6,1,3,5,7
SkipResidentChunks:
 lda #1
 sta S_PREPARING
@chunk:
 lda S_STREAM
 beq @done
 cmp #9
 bcs @done
 tax
 dex
 ldy PendingIndex,x
 lda S_PENDINGCHUNKS,y
 pha
 lda S_ACTIVE
 cmp #8
 bne :+
 txa
 ora #8
 tax
:
 pla
 cmp S_CHUNKCACHE,x
 bne @done
 inc S_STREAM
 jmp @chunk
@done:
 lda #0
 sta S_PREPARING
 rts
UploadStep:
 lda S_STREAM
 asl
 tax
 lda UploadSteps-1,x
 pha
 lda UploadSteps-2,x
 pha
 rts
UploadSteps:
 .word UploadChunk0-1,UploadChunk1-1,UploadChunk2-1,UploadChunk3-1
 .word UploadChunk4-1,UploadChunk5-1,UploadChunk6-1,UploadChunk7-1
CommitDirections:
 ldx #1
@body:
 lda S_DRAWN,x
 beq @other
 lda S_PPOWER,x
 cmp S_APOWER,x
 bne @pendingBody
@other:
 dex
 bpl @body
 bmi @commit
@pendingBody:
 lda S_COMMITREADY
 beq @wait
 lda #$7A
 sta S_DMAPAGE
@commit:
 lda #0
 sta S_STREAM
 sta S_COMMITREADY
 ldx #1
@meta:
 lda S_PID,x
 sta S_AID,x
 lda S_PPOWER,x
 sta S_APOWER,x
 lda S_PDIR,x
 sta S_ADIR,x
 dex
 bpl @meta
 lda S_ACTIVE
 eor #2
 sta S_ACTIVE
 sta S_FRAMEBANK
 jmp RawChr0
@wait:
 rts
PrepareCommitOam:
 jsr SkipResidentChunks
 lda S_STREAM
 cmp #9
 bne @done
 ; Build the complete alternate OAM page in main time. The NMI then
 ; switches its DMA source, avoiding 1,024 cycles of two-player copying
 ; inside vblank when both bodies grow/shrink at once.
 ldy #0
@copy:
 lda $0200,y
 sta $7A00,y
 iny
 bne @copy
 lda #0
 sta S_ACTOR
@player:
 ldy S_ACTOR
 lda S_DRAWN,y
 beq @next
 lda S_OAMSTART,y
 sta S_OAM
 tax
 lda #$7A
 sta S_DESTHI
 lda S_PPOWER,y
 sta S_SELECTED
 lda S_PDIR,y
 sta S_ATTR
 jsr RenderDirection
@next:
 inc S_ACTOR
 lda S_ACTOR
 cmp #2
 bcc @player
 lda #1
 sta S_COMMITREADY
@done:
 rts
SceneGate:
 jsr $918B
 lda $56
 pha
 jsr FireUpdate
 pla
 sta $56
 rts
FireUpdate:
 ldx #0
@player:
 stx S_OWNER
 lda $049B,x
 beq @other
 cmp #3
 bcs @other
 lda S_POWER,x
 cmp #2
 bne @other
 lda S_FIREEDGE,x
 and #$40
 beq @other
 jsr SpawnShot
@other:
 ldx S_OWNER
 lda #0
 sta S_FIREEDGE,x
 inx
 cpx #2
 bcc @player
 ldx #0
@shot:
 stx S_SHOT
 lda S_FL,x
 jeq @next
 dec S_FL,x
 lda S_FDX,x
 bmi @negx
 ldy #0
 beq @x
@negx: ldy #$FF
@x:
 clc
 adc S_FX,x
 sta S_FX,x
 tya
 adc S_FXH,x
 sta S_FXH,x
 lda S_FDY,x
 bmi @negy
 ldy #0
 beq @y
@negy: ldy #$FF
@y:
 clc
 adc S_FY,x
 sta S_FY,x
 tya
 adc S_FYH,x
 sta S_FYH,x
 ; Bounce in the vertical world axis, independently of the camera.
 lda S_FVF,x
 sec
 sbc #$60
 sta S_FVF,x
 lda S_FV,x
 sbc #0
 sta S_FV,x
 bmi @down
 ldy #0
 beq @z
@down: ldy #$FF
@z:
 lda S_FP,x
 clc
 adc S_FVF,x
 sta S_FP,x
 lda S_FZ,x
 adc S_FV,x
 sta S_FZ,x
 tya
 adc S_FZH,x
 sta S_FZH,x
 lda S_FV,x
 bpl @collision
 lda S_FZH,x
 cmp S_FGH,x
 bcc @bounce
 bne @collision
 lda S_FZ,x
 cmp S_FGROUND,x
 bcs @collision
@bounce:
 lda S_FGROUND,x
 sta S_FZ,x
 lda S_FGH,x
 sta S_FZH,x
 lda #2
 sta S_FV,x
 lda #0
 sta S_FVF,x
@collision:
 jsr ProjectShot
 jcs @next
 ldy #2
@target:
 sty S_TARGET
 lda $049B,y
 jeq @otherTarget
 tay
 lda FireTargets,y
 jeq @otherTarget
 ldy S_TARGET
 ; World coordinates prevent hits on platforms above/below the shot.
 lda S_FXH,x
 cmp $04C3,y
 jne @otherTarget
 lda S_FYH,x
 cmp $04EB,y
 jne @otherTarget
 lda S_FZH,x
 cmp $0513,y
 jne @otherTarget
 lda S_FX,x
 sec
 sbc $04D7,y
 clc
 adc #12
 cmp #25
 bcs @otherTarget
 lda S_FY,x
 sec
 sbc $04FF,y
 clc
 adc #12
 cmp #25
 bcs @otherTarget
 lda S_FZ,x
 sec
 sbc $0527,y
 clc
 adc #2
 cmp #25
 bcs @otherTarget
 jsr FireHit
 ldx S_SHOT
 lda #0
 sta S_FL,x
 jmp @next
@otherTarget:
 ldy S_TARGET
 iny
 cpy #20
 jne @target
@next:
 ldx S_SHOT
 inx
 cpx #4
 jne @shot
 rts
FireHit:
 ; The native tongue's target damage includes the bosses' real HP and
 ; defeat/progression logic. Both attacks use that same path.
 sty $56
 lda S_SHOT
 lsr
 sta $0B
 tya
 tax
 ldy $0B
 jmp $BBDE
SpawnShot:
 txa
 asl
 tay
 lda S_FL,y
 beq @found
 iny
 lda S_FL,y
 bne @done
@found:
 lda #48
 sta S_FL,y
 lda $04D7,x
 sta S_FX,y
 lda $04C3,x
 sta S_FXH,y
 lda $04FF,x
 sta S_FY,y
 lda $04EB,x
 sta S_FYH,y
 lda $0527,x
 clc
 adc #6
 sta S_FZ,y
 sta S_FGROUND,y
 lda $0513,x
 adc #0
 sta S_FZH,y
 sta S_FGH,y
 lda #0
 sta S_FV,y
 sta S_FVF,y
 sta S_FP,y
 lda S_LASTDIR,x
 and #$0F
 tax
 lda FireDX,x
 sta S_FDX,y
 lda FireDY,x
 sta S_FDY,y
@done: rts
ProjectShot:
 lda S_FX,x
 clc
 adc S_FY,x
 sta $04
 lda S_FXH,x
 adc S_FYH,x
 sta $05
 lda $04
 sec
 sbc $6E
 sta S_FSX,x
 lda $05
 sbc $6D
 bne @off
 lda S_FX,x
 sec
 sbc S_FY,x
 sta $04
 lda S_FXH,x
 sbc S_FYH,x
 ror
 ror $04
 sta $05
 lda $04
 sec
 sbc S_FZ,x
 sta $04
 lda $05
 sbc S_FZH,x
 sta $05
 lda $04
 clc
 adc $C3
 bcc :+
 inc $05
:
 sec
 sbc $70
 sta S_FSY,x
 lda $05
 sbc $6F
 and #$3F
 bne @off
 clc
 rts
@off: sec
 rts
FireDraw:
 stx S_OAM
 ldy #0
FireDrawShot:
 sty S_SHOT
 lda S_FL,y
 beq FireDrawNext
 ldx S_OAM
 cpx #$F8
 bcs FireDrawDone
 ldx S_SHOT
 jsr ProjectShot
 bcs FireDrawNext
 ldy S_SHOT
 ldx S_OAM
 lda S_FSY,y
 sta $0200,x
 lda $02
 and #4
 lsr
 lsr
 clc
 tay
ShotTiles:
 lda #FireSlot
 sta $0201,x
ShotFlip:
 lda FireFlip,y
 sta $0202,x
 ldy S_SHOT
 lda S_FSX,y
 sta $0203,x
 inx
 inx
 inx
 inx
 stx S_OAM
FireDrawNext:
 ldy S_SHOT
 iny
 cpy #4
 bcc FireDrawShot
FireDrawDone:
 ldx S_OAM
 jmp $816E
FireDX: .byte 2,3,$FD,0,0,2,$FE,0,0,2,$FE,0,0,0,0,0
FireDY: .byte 2,0,0,0,$FD,$FE,$FE,0,3,2,2,0,0,0,0,0
FireTargets:
 .repeat 64,I
  .if I=$0E .or I=$13 .or I=$14 .or I=$15 .or I=$16 .or I=$1A .or I=$22 .or I=$2C .or I=$35 .or I=$38 .or I=$39 .or I=$3B
   .byte 1
  .else
   .byte 0
  .endif
 .endrepeat
FireFlip: .byte 0,192
.include "directional.inc"


.segment "FRAMECOPY"
CopyFrame0:
 ldy #0
 .repeat 256,I
 lda ($08),y
 sta $7200+I
 iny
 .endrepeat
 rts
CopyFrame1:
 ldy #0
 .repeat 256,I
 lda ($08),y
 sta $7300+I
 iny
 .endrepeat
 rts

; Original SMB1 growth and shrink poses. Intermediate art is frame 25.
MorphFrame:
    lda M_TRANSFORM
    cmp #2
    beq @fire
    lda #40
    sec
    sbc M_POWER_FREEZE
    lsr
    lsr
    cmp #10
    bcc :+
    lda #9
:
    tay
    lda M_TRANSFORM
    bne @shrink
    lda GrowPoses,y
    rts
@shrink:
    lda ShrinkPoses,y
    rts
@fire:
    lda #24
    rts
GrowPoses: .byte 23,25,23,25,23,25,24,23,25,24
ShrinkPoses: .byte 17,5,17,5,17,5,17,5,17,5

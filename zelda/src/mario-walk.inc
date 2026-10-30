; The native vertical gait flips the pose every six moving frames. The
; reference head is symmetric, so a pronounced asymmetric stride gives
; alternating feet with a steady face. Stand and attack retain their poses.
    CPX #0
    BNE @MarioWalkDone
    LDA ObjDir
    AND #$0C
    BEQ @MarioWalkDone
    LDA ObjState
    BNE @MarioWalkDone
    LDA ObjInputDir
    BNE @MarioWalking
    LDA GameMode
    CMP #4
    BEQ @MarioWalking
    CMP #$10
    BNE @MarioWalkDone
@MarioWalking:
    LDA ObjDir
    AND #8
    BEQ @MarioWalkFront
    LDA #$54
    STA $02
    LDA #$60
    BNE @MarioWalkRightTile
@MarioWalkFront:
    LDA #$5C
    STA $02
    LDA #$5E
@MarioWalkRightTile:
    STA $03
@MarioWalkDone:

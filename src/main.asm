INCLUDE "./src/hardware.inc"
INCLUDE "./src/macro.inc"

; Constant
DEF BRICK_LEFT EQU $05
DEF BRICK_RIGHT EQU $06
DEF BLANK_TILE EQU $08

CHARMAP "a", $20
CHARMAP "b", $21
CHARMAP "c", $22
CHARMAP "d", $23
CHARMAP "e", $24
CHARMAP "f", $25
CHARMAP "g", $26
CHARMAP "h", $27
CHARMAP "i", $28
CHARMAP "j", $29
CHARMAP "k", $2a
CHARMAP "l", $2b
CHARMAP "m", $2c
CHARMAP "n", $2d
CHARMAP "o", $2e
CHARMAP "p", $2f
CHARMAP "q", $30
CHARMAP "r", $31
CHARMAP "s", $32
CHARMAP "t", $33
CHARMAP "u", $34
CHARMAP "v", $35
CHARMAP "w", $36
CHARMAP "x", $37
CHARMAP "y", $38
CHARMAP "z", $39
CHARMAP "0", $3a
CHARMAP "1", $3b
CHARMAP "2", $3c
CHARMAP "3", $3d
CHARMAP "4", $3e
CHARMAP "5", $3f
CHARMAP "6", $40
CHARMAP "7", $41
CHARMAP "8", $42
CHARMAP "9", $43
CHARMAP "!", $44
CHARMAP "?", $45
CHARMAP ".", $46

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @, 0 ; Make room for the header

SECTION "Commons", ROM0
INCLUDE "./src/common.inc"

; @destroy a
WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank
    ret

MACRO SHAKE
    ld a, \1
    ld [wShakeTimer], a
ENDM

BounceSFX:
    ld a, $00
    ld [rNR10], a
    ld a, $35
    ld [rNR11], a
    ld a, $f1
    ld [rNR12], a
    ld a, $73
    ld [rNR13], a
    ld a, $86
    ld [rNR14], a
    ret

PlopSFX:
    ld a, $2a
    ld [rNR10], a
    ld a, $02
    ld [rNR11], a
    ld a, $f7
    ld [rNR12], a
    ld a, $73
    ld [rNR13], a
    ld a, $c6
    ld [rNR14], a
    ret

; @destroy A, B, C
ShakeScreen::
    ld a, [wOriginalCameraY]
    ld [rSCY], a
    ld a, [wOriginalCameraX]
    ld [rSCX], a

    ld a, [wShakeTimer]
    and a
    ret z
ShakeScreen_Main:
    dec a
    ld [wShakeTimer], a

    ld a, [rSCX]
    add a, $1
    ld [rSCX], a

    ld a, [rSCY]
    add a, $1
    ld [rSCY], a

    ret

IncreaseScore::
    ; We have 6 digits, start with the right-most digit (the last byte)
    ld c, 0
    ld hl, wScore+2

IncreaseScore_Loop:
    ; Increase the digit 
    ld a, [hl]
    inc a
    ld [hl], a

    ; Stop if it hasn't gone past 0
    cp 9
    ret c

; If it HAS gone past 9
IncreaseScore_Next:
    ; Increase a counter so we can not go out of our scores bounds
    inc c
    ld a, c

    ; Check if we've gone over our scores bounds
    cp 6
    ret z

    ; Reset the current digit to zero
    ; Then go to the previous byte (visually: to the left)
    ld a, 0
    ld [hl], a
    ld [hld], a

    jp IncreaseScore_Loop


DrawScore::
    ; Our score has max 6 digits
    ; We'll start with the left-most digit (visually) which is also the first byte
    ld c, 3
    ld hl, wScore
    ld de, $984e ; The window tilemap starts at $9C00

DrawScore_Loop:
    ld a, [hli]
    add $3a  ; our numeric tiles start at tile 10, so add to 10 to each bytes value
    ld [de], a

    ; Decrease how many numbers we have drawn
    dec c
        
    ; Stop when we've drawn all the numbers
    ret z

    ; Increase which tile we are drawing to
    inc de

    jp DrawScore_Loop

UpdateKeys:
  ; Poll half the controller
  ld a, P1F_GET_BTN
  call .onenibble
  ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

  ; Poll the other half
  ld a, P1F_GET_DPAD
  call .onenibble
  swap a ; A3-0 = unpressed directions; A7-4 = 1
  xor a, b ; A = pressed buttons + directions
  ld b, a ; B = pressed buttons + directions

  ; And release the controller
  ld a, P1F_GET_NONE
  ldh [rP1], a

  ; Combine with previous wCurKeys to make wNewKeys
  ld a, [wCurKeys]
  xor a, b ; A = keys that changed state
  and a, b ; A = keys that changed to pressed
  ld [wNewKeys], a
  ld a, b
  ld [wCurKeys], a
  ret

.onenibble
  ldh [rP1], a ; switch the key matrix
  call .knownret ; burn 10 cycles calling a known ret
  ldh a, [rP1] ; ignore value while waiting for the key matrix to settle
  ldh a, [rP1]
  ldh a, [rP1] ; this read counts
  or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
  ret

; Convert a pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
    ; First, we need to divide by 8 to convert a pixel position to a tile position.
    ; After this we want to multiply the Y position by 32.
    ; These operations effectively cancel out so we only need to mask the Y value.
    ld a, c
    and a, %11111000
    ld l, a
    ld h, 0
    ; Now we have the position * 8 in hl
    add hl, hl ; position * 16
    add hl, hl ; position * 32
    ; Convert the X position to an offset.
    ld a, b
    srl a ; a / 2
    srl a ; a / 4
    srl a ; a / 8
    ; Add the two offsets together.
    add a, l
    ld l, a
    adc a, h
    sub a, l
    ld h, a
    ; Add the offset to the tilemap's base address, and we are done!
    ld bc, $9800
    add hl, bc
    ret

; @param a: tile ID
; @return z: set if a is a wall.
IsWallTile:
    cp a, $00
    ret z
    cp a, $01
    ret z
    cp a, $02
    ret z
    cp a, $04
    ret z
    cp a, $05
    ret z
    cp a, $06
    ret z
    cp a, $07
    ret

; Checks if a brick was collided with and breaks it if possible.
; @param hl: address of tile.
CheckAndHandleBrick:
    ld a, [hl]
    cp a, BRICK_LEFT
    jr nz, CheckAndHandleBrickRight
    ; Break a brick from the left side.
    ld [hl], BLANK_TILE
    inc hl
    ld [hl], BLANK_TILE
    push hl
    call IncreaseScore
    SHAKE $4
    call PlopSFX
    pop hl
CheckAndHandleBrickRight:
    cp a, BRICK_RIGHT
    ret nz
    ; Break a brick from the right side.
    ld [hl], BLANK_TILE
    dec hl
    ld [hl], BLANK_TILE
    call IncreaseScore
    call PlopSFX
    SHAKE $4
    ret

SECTION "Code", ROM0
EntryPoint:

    ; Do not turn the LCD off outside of VBlank
    call WaitVBlank

    ; Turn the LCD off
    LCD 0

InitTile:
    ; Copy the tile data
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
    call Memcopy

    ; Copy the tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
    call Memcopy

    ; Write score Text to tilemap
    ld de, ScoreText
    ld hl, $982e
    ld bc, ScoreTextEnd - ScoreText
    call Memcopy
InitFont:
    ld de, Font
    ld hl, $9200
    ld bc, FontEnd - Font
    call Memcopy


InitOam:
    ; Init OAM
    ld a, 0
    ld b, 160
    ld hl, _OAMRAM
ClearOam:
    ld [hli], a
    dec b
    jp nz, ClearOam

    ; Copy the ball tile
    ld de, Paddle
    ld hl, $8000
    ld bc, PaddleEnd - Paddle
    call Memcopy

    ; Copy the ball tile
    ld de, Ball
    ld hl, $8010
    ld bc, BallEnd - Ball
    call Memcopy

    ; Initialize the paddle sprite in OAM
    ld hl, _OAMRAM
    ld a, 128 + 16      ; Y Position
    ld [hli], a         ; Set Y Position and Inc
    ld a, 16 + 8        ; X Position
    ld [hli], a         ; Set X Position and Inc
    ld a, 0             ; Set sprite id
    ld [hli], a         ; Set Sprite id and Inc
    ld [hli], a         ; Skip attribute

    ; Now initialize the ball sprite
    ld a, 100 + 16
    ld [hli], a
    ld a, 32 + 8
    ld [hli], a
    ld a, 1
    ld [hli], a
    ld a, 0
    ld [hli], a

    ld a, 1
    ld [wBallMomentumX], a
    ld a, -1
    ld [wBallMomentumY], a

TurnOnDisplay:
    ; Turn the LCD on
    LCD LCDCF_ON | LCDCF_BGON | LCDCF_OBJON

    ; During the first (blank) frame, initialize display registers
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
    ld [rOBP0], a

    ; Set soundchip on
    ld a, AUDENA_ON
    ld [rNR52], a
    ld a, $FF
    ld [rNR51], a
    ld a, $77
    ld [rNR51], a

    ld a, 0
    ld [wCurKeys], a
    ld [wNewKeys], a
    ld [wShakeTimer], a
    ld [wOriginalCameraX], a
    ld [wOriginalCameraY], a
    ld [wScore], a
    ld [wScore + 1], a
    ld [wScore + 2], a
Main:
    ; Wait until it's *not* VBlank
    ld a, [rLY]
    cp 144
    jp nc, Main
    call WaitVBlank
    call ShakeScreen
    call DrawScore

    ; Add the ball's momentum to its position in OAM.
    ld a, [wBallMomentumX]
    ld b, a
    ld a, [_OAMRAM + 5]
    add a, b
    ld [_OAMRAM + 5], a

    ld a, [wBallMomentumY]
    ld b, a
    ld a, [_OAMRAM + 4]
    add a, b
    ld [_OAMRAM + 4], a

BounceOnTop:
    ; Remember to offset the OAM position!
    ; (8, 16) in OAM coordinates is (0, 0) on the screen.
    ld a, [_OAMRAM + 4]
    sub a, 16 + 1
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel ; Returns tile address in hl
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnRight
    call CheckAndHandleBrick
    ld a, 1
    ld [wBallMomentumY], a

BounceOnRight:
    ld a, [_OAMRAM + 4]
    sub a, 16
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8 - 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnLeft
    call CheckAndHandleBrick
    ld a, -1
    ld [wBallMomentumX], a

BounceOnLeft:
    ld a, [_OAMRAM + 4]
    sub a, 16
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8 + 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnBottom
    call CheckAndHandleBrick
    ld a, 1
    ld [wBallMomentumX], a

BounceOnBottom:
    ld a, [_OAMRAM + 4]
    sub a, 16 - 1
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceDone
    call CheckAndHandleBrick
    ld a, -1
    ld [wBallMomentumY], a
BounceDone:

    ; First, check if the ball is low enough to bounce off the paddle.
    ld a, [_OAMRAM]
    ld b, a
    ld a, [_OAMRAM + 4]
    add a, 6
    cp a, b
    jp nz, PaddleBounceDone ; If the ball isn't at the same Y position as the paddle, it can't bounce.
    ; Now let's compare the X positions of the objects to see if they're touching.
    ld a, [_OAMRAM + 5] ; Ball's X position.
    ld b, a
    ld a, [_OAMRAM + 1] ; Paddle's X position.
    sub a, 8
    cp a, b
    jp nc, PaddleBounceDone
    add a, 8 + 16 ; 8 to undo, 16 as the width.
    cp a, b
    jp c, PaddleBounceDone

    ld a, -1
    ld [wBallMomentumY], a
    call BounceSFX

PaddleBounceDone:

    ; Check the current keys every frame and move left or right.
    call UpdateKeys

    ; First, check if the left button is pressed.
CheckLeft:
    ld a, [wCurKeys]
    and a, PADF_LEFT
    jp z, CheckRight
Left:
    ; Move the paddle one pixel to the left.
    ld a, [_OAMRAM + 1]
    dec a

    ; If we've already hit the edge of the playfield, don't move.
    cp a, 15
    jp z, Main
    ld [_OAMRAM + 1], a
    jp Main

; Then check the right button.
CheckRight:
    ld a, [wCurKeys]
    and a, PADF_RIGHT
    jp z, Main
Right:
    ; Move the paddle one pixel to the right.
    ld a, [_OAMRAM + 1]
    inc a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 105
    jp z, Main
    ld [_OAMRAM + 1], a
    jp Main

SECTION "Assets", ROM0
INCLUDE "./src/assets.inc"

ScoreText: db "score"
ScoreTextEnd:

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db

SECTION "Ball Data", WRAM0
wBallMomentumX: db
wBallMomentumY: db

SECTION "GameplayState", WRAM0
wScore:: ds 3
wLives:: db
wShakeTimer:: db
wOriginalCameraX:: db
wOriginalCameraY:: db

SECTION "MathVariables", WRAM0
randstate:: ds 4


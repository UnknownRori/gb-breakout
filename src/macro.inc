; @destroy a
MACRO LCD
    ld a, \1
    ld [rLCDC], a
ENDM

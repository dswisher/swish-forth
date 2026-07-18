; hello.asm - Lab 1: Hello, X16!

; KERNAL routines
CHROUT = $FFD2
CLRCHN = $FFCC

; --- PRG stub ---
.segment "HEADER"
    .word $0801

; --- BASIC stub ---
; This sits at $0801 and tricks BASIC into thinking there is a one-line
; BASIC program that reads: 10 SYS 2061
; $2061 is the start of our actual code (just after the stub).

.segment "BASICSTUB"
    .word $080D         ; pointer to next BASIC line
    .word 10            ; line number 10
    .byte $9E           ; BASIC token for SYS
    .byte "2061"        ; address as ASCII digits
    .byte 0             ; end of BASIC line
    .word 0             ; end of BASIC program

; --- Our code starts here ($080B) ---
.segment "CODE"

main:
    ; Your code here:
    ; Loop through the message and call CHROUT for each character,
    ; then call CLRCHN and RTS.
    ldx #0
    lda message,x
    jsr CHROUT
    lda #$0D
    jsr CHROUT

    ; jsr CLRCHN
    rts

message:
    .byte "Hello, X16!", $0D, 0


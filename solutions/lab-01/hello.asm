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
; $080D is the start of our actual code (just after the stub).

.segment "BASICSTUB"
    .word $080D         ; pointer to next BASIC line
    .word 10            ; line number 10
    .byte $9E           ; BASIC token for SYS
    .byte "2061"        ; address as ASCII digits
    .byte 0             ; end of BASIC line
    .word 0             ; end of BASIC program

; --- Our code starts here ($080D) ---
.segment "CODE"

main:
    ldx #0              ; index into the string
loop:
    lda message,x       ; get the character based on the index
    beq done            ; if zero, we're done
    jsr CHROUT          ; spit out the character
    inx                 ; bump the index
    jmp loop            ; go around again

done:
    jsr CLRCHN          ; it is polite to make sure the I/O channels are reset
    rts                 ; back to BASIC

message:
    .byte "HELLO, X16!", $0D, 0


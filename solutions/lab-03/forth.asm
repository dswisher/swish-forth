; forth.asm - lab 2: NEXT

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

; Zero page layout
W   = $22       ; working register (2 bytes: $22-$23)
IP  = $24       ; instruction pointer (2 bytes: $24-$25)

; The NEXT macro, which appears at the end of every primitive
.macro NEXT
    ldy #0
    lda (IP),y      ; W_lo = memory[IP]
    sta W
    iny
    lda (IP),y      ; W_hi = memory[IP+1]
    sta W+1
    clc             ; Advance IP by 2
    lda IP
    adc #2
    sta IP
    bcc :+          ; branch to the anonymous label 2 lines below
    inc IP+1
:
    jmp (W)         ; jump to the address stored at W
.endmacro

; --- Our code starts here ($080D) ---
.segment "CODE"

main:
    ; Set IP to test_thread
    lda #<test_thread
    sta IP
    lda #>test_thread
    sta IP+1

    ; invoke the inner interpreter
    NEXT

; The test thread: a list of CFAs
test_thread:
    .word cfa_foo       ; pointer to foo's CFA
    .word cfa_bar       ; pointer to bar's CFA
    ; (no exit yet - the thread will run off the end for now)

; Primitive: FOO
; The CFA of a primitive points to its own code.
cfa_foo:
    .word code_foo      ; CFA cell: points to the machine code below
code_foo:
    ; ... do nothing for now ...
    nop
    NEXT

; Primitive: BAR
cfa_bar:
    .word code_bar
code_bar:
    ; ... do nothing for now ...
    nop
    nop
    NEXT


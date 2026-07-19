; forth.asm - lab 4: DOCOL and EXIT

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
WX  = $26       ; scratch register for NEXT (2 bytes: $26-$27)


; --- Our code starts here ($080D) ---
.segment "CODE"

main:
    ; Set IP to test_thread
    lda #<test_thread
    sta IP
    lda #>test_thread
    sta IP+1

    ; invoke the inner interpreter
    jmp NEXT

; The test thread: a list of CFAs
test_thread:
    .word cfa_outer
    .word cfa_exit

; Colon definition: OUTER
cfa_outer:
    .word DOCOL
    .word cfa_inner
    .word cfa_exit

; Colon definition: INNER
cfa_inner:
    .word DOCOL
    .word cfa_foo
    .word cfa_bar
    .word cfa_exit

; Primitive: FOO
; The CFA of a primitive points to its own code.
cfa_foo:
    .word code_foo      ; CFA cell: points to the machine code below
code_foo:
    ; ... do nothing for now ...
    nop
    jmp NEXT

; Primitive: BAR
cfa_bar:
    .word code_bar
code_bar:
    ; ... do nothing for now ...
    nop
    nop
    jmp NEXT


; NEXT - move on to the next word
; Note that the lab has this has a macro, but I'm experimenting with having it as
; as subroutine
NEXT:
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
    bcc :+          ; jump to the next anonymous label
    inc IP+1
:
    ; W holds the CFA address - read through it to get the code address
    ldy #0
    lda (W),y       ; WX_lo = memory[W]
    sta WX
    iny
    lda (W),y       ; WX_hi = memory[W+1]
    sta WX+1
    jmp (WX)        ; W -> CFA -> Code

; DOCOL - the CFA of every non-primitive FORTH word
DOCOL:
    ; Push current IP onto the return stack
    lda IP+1
    pha
    lda IP
    pha

    ; Set IP to the PFA (W + 2)
    clc
    lda W
    adc #2
    sta IP
    lda W+1
    adc #0          ; carry from previous add
    sta IP+1

    ; Resume the inner interpreter
    jmp NEXT


; ----------------------------------------
;            Primitive Words
; ----------------------------------------

; EXIT - exits the current word
cfa_exit:
    .word code_exit
code_exit:
    ; Pop IP from the return stack
    pla
    sta IP
    pla
    sta IP+1
    jmp NEXT


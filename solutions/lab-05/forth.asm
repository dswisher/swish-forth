; forth.asm - lab 5: Primitive Words - Stack, Arithmetic, and Memory

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
W    = $22       ; working register (2 bytes: $22-$23)
IP   = $24       ; instruction pointer (2 bytes: $24-$25)
WX   = $26       ; scratch register for NEXT (2 bytes: $26-$27) and primitive work area

PSP  = $00       ; parameter stack base (X register is the offset, starts at FF and works down)


; --- Our code starts here ($080D) ---
.segment "CODE"

main:
    ; Initialize the parameter stack
    ldx #$FF

    ; Push some test values on the stack, until we get LIT implemented
    ; push one value
    dex
    dex
    lda #$05
    sta PSP+0,x
    lda #$00
    sta PSP+1,x

    ; push a second value
    dex
    dex
    lda #$50
    sta PSP+0,x
    lda #$00
    sta PSP+1,x

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
    .word cfa_store
    .word cfa_exit



; NEXT - move on to the next word, as a subroutine instead of a macro
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


; DUP ( n -- n n ) duplicates the top of stack.
cfa_dup:
    .word code_dup
code_dup:
    lda PSP+0,x     ; load TOS lo
    ldy PSP+1,x     ; load TOS hi
    dex
    dex
    sta PSP+0,x     ; push copy lo
    tya
    sta PSP+1,x     ; push copy hi
    jmp NEXT


; DROP ( n -- ) discards the top of stack.
cfa_drop:
    .word code_drop
code_drop:
    inx
    inx
    jmp NEXT


; SWAP ( a b -- b a ) exchanges the top two items.
cfa_swap:
    .word code_swap
code_swap:
    lda PSP+0,x     ; load TOS lo
    pha
    lda PSP+1,x     ; load TOS hi
    pha
    lda PSP+2,x     ; load NOS lo
    sta PSP+0,x
    lda PSP+3,x     ; load NOS hi
    sta PSP+1,x
    pla             ; reload TOS hi
    sta PSP+3,x
    pla             ; reload TOS lo
    sta PSP+2,x
    jmp NEXT


; OVER ( a b -- a b a ) copies second item to the top
cfa_over:
    .word code_over
code_over:
    lda PSP+3,x     ; load NOS lo
    ldy PSP+2,x     ; load NOS hi
    dex
    dex
    sta PSP+0,x     ; push copy lo
    tya
    sta PSP+1,x     ; push copy hi
    jmp NEXT


; + ( a b -- a+b ) 16-bit addition
cfa_plus:
    .word code_plus
code_plus:
    clc
    lda PSP+0,x     ; load TOS lo
    adc PSP+2,x     ; add NOS lo
    sta PSP+2,x     ; save new TOS lo
    lda PSP+1,x     ; load TOS hi
    adc PSP+3,x     ; add NOS hi
    sta PSP+3,x     ; save new TOS hi
    inx
    inx
    jmp NEXT


; - ( a b -- a-b ) 16-bit subtraction
cfa_minus:
    .word code_minus
code_minus:
    sec
    lda PSP+2,x     ; load NOS lo
    sbc PSP+0,x     ; subtract TOS lo
    sta PSP+2,x     ; save new TOS lo
    lda PSP+3,x     ; load NOS hi
    sbc PSP+1,x     ; subtract TOS hi
    sta PSP+3,x     ; save new TOS hi
    inx
    inx
    jmp NEXT


; 1+ ( n -- n+1 ) increment by 1
cfa_one_plus:
    .word code_one_plus
code_one_plus:
    inc PSP+0,x     ; increment lo
    bne :+          ; if no carry (non-zero result), we're done
    inc PSP+1,x     ; increment hi
:   jmp NEXT


; 1- ( n -- n-1 ) decrement by 1
cfa_one_minus:
    .word code_one_minus
code_one_minus:
    sec
    lda PSP+0,x     ; load TOS lo
    sbc #$01        ; subtract 1
    sta PSP+0,x     ; save new TOS lo
    lda PSP+1,x     ; load TOS hi
    sbc #$00        ; subtract borrow
    sta PSP+1,x     ; save new TOS hi
    jmp NEXT

; @ ( addr -- n ) fetch 16-bit value from address
cfa_fetch:
    .word code_fetch
code_fetch:
    ; put address in WX
    lda PSP+0,x     ; load TOS lo
    sta WX+0        ; store temp lo
    lda PSP+1,x     ; load TOS lo
    sta WX+1        ; store temp lo

    ; fetch the value
    ldy #$00
    lda (WX),y      ; get lo value from address
    sta PSP+0,x     ; store lo
    iny
    lda (WX),y      ; get hi value from address
    sta PSP+1,x     ; store hi
    jmp NEXT

; ! ( n addr -- ) store 16-bit value to address
cfa_store:
    .word code_store
code_store:
    ; put address in WX
    lda PSP+0,x     ; load address (TOS) lo
    sta WX+0        ; store temp lo
    lda PSP+1,x     ; load address lo
    sta WX+1        ; store temp lo

    ; store the value
    ldy #$00
    lda PSP+2,x     ; load value (NOS) lo
    sta (WX),y      ; save lo value to addr lo
    iny
    lda PSP+3,x     ; load value (NOS) hi
    sta (WX),y      ; save hi value to addr hi

    ; clear the stack
    inx
    inx
    inx
    inx
    jmp NEXT


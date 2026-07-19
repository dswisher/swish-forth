; forth.asm - lab 6: LIT, the Dictionary, and FIND

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
LEN  = $28       ; length used during string compare
ADDR = $29       ; base address, used during string compare

PSP  = $00       ; parameter stack base (X register is the offset, starts at FF and works down)


; --- Our code starts here ($080D) ---
.segment "CODE"

main:
    ; Initialize the parameter stack
    ldx #$FF

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
    .word cfa_bye

; Colon definition: OUTER
cfa_outer:
    .word DOCOL
    .word cfa_lit, FIND_GOAL+1
    .word cfa_lit, FIND_LEN
    .word cfa_find
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
    lda PSP+2,x     ; load NOS lo
    ldy PSP+3,x     ; load NOS hi
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
    lda PSP+1,x     ; load TOS hi
    sta WX+1        ; store temp hi

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


; BYE ( -- ) break execution - seems to drop to MON on the X16
dict_bye:
    .word $0000     ; for the moment, end the dictionary list here
    .byte 3, "BYE"
cfa_bye:
    .word code_bye
code_bye:
    brk


; LIT ( -- n ) pushes a literal on the stack
dict_lit:
    .word dict_bye
    .byte 3, "LIT"
cfa_lit:
    .word code_lit
code_lit:
    ; push memory[IP]
    dex             ; make room on the stack
    dex
    ldy #$00
    lda (IP),y      ; load literal lo
    sta PSP+0,x     ; store lo
    iny
    lda (IP),y      ; load literal hi
    sta PSP+1,x     ; store hi

    ; IP = IP + 2
    lda IP
    adc #2
    sta IP
    bcc :+          ; skip if no carry
    inc IP+1

:   jmp NEXT


; FIND ( addr len -- cfa | 0 ) look up a word in the dictionary
dict_find:
    .word dict_lit
    .byte 4, "FIND"
cfa_find:
    .word code_find
code_find:
    ; pull the parameters off the stack, leaving room for the one we'll add
    ; TODO - subtract 2 from the address before storing it
    lda PSP+2,x     ; load TOS lo
    ldy PSP+3,x     ; load TOS hi
    sta ADDR+0      ; save lo
    sty ADDR+1      ; save hi

    lda PSP+0,x     ; load NOS lo
    sta LEN         ; save len

    inx
    inx

    ; entry (wx) = memory[LATEST]      ; start at the most recent entry
    lda LATEST      ; load address (TOS) lo
    sta WX+0        ; store temp lo
    lda LATEST+1    ; load address (TOS) lo
    sta WX+1        ; store temp lo

find_loop:
    ; if entry is zero, we're done
    lda WX
    ora WX+1
    beq find_no_match

    ; check if the length (WX),2 is a match
    ldy #$02
    lda (WX),y      ; get lo value from address
    cmp LEN
    bne find_loop

    ; check to see if the string matches
    ; TODO - save X on the stack, then use it as a loop counter to check the string

    nop             ; pattern so I can see this spot in the debugger
    nop
    nop

find_next:
    ; This one isn't a match, go look for the next one
    ;     entry = memory[entry]               ; follow the link
    ldy #$00
    lda (WX),y      ; get lo value from address
    pha
    iny
    lda (WX),y      ; get hi value from address
    sta WX+1        ; store hi
    pla
    sta WX+0        ; store lo

    jmp find_loop

find_no_match:
    lda #$00
    sta PSP+0,x
    sta PSP+1,x
    jmp NEXT


; entry = memory[LATEST]      ; start at the most recent entry
; while entry != 0:
;     name_len = memory[entry + 2]        ; length byte of this entry
;     if name_len == len:
;         if memory[entry + 3 .. entry + 3 + len] == string:
;             return entry + 3 + len      ; CFA is right after the name
;     entry = memory[entry]               ; follow the link
; return 0


; Pointer to the first dictionary entry
LATEST:
    .word dict_find

; Testing
FIND_LEN = 4
FIND_GOAL:
    .byte "FIND"


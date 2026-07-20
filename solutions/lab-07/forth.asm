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
    .word cfa_lit, $2445    ; a
    .word cfa_lit, $2345    ; b
    .word cfa_greater_than  ; a > b
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
dict_exit:
    .word $0000
    .byte 4, "EXIT"
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
dict_dup:
    .word dict_exit
    .byte 3, "DUP"
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
dict_drop:
    .word dict_dup
    .byte 4, "DROP"
cfa_drop:
    .word code_drop
code_drop:
    inx
    inx
    jmp NEXT


; SWAP ( a b -- b a ) exchanges the top two items.
dict_swap:
    .word dict_drop
    .byte 4, "SWAP"
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
dict_over:
    .word dict_swap
    .byte 4, "OVER"
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
dict_plus:
    .word dict_over
    .byte 1, "+"
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
dict_minus:
    .word dict_plus
    .byte 1, "-"
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
dict_one_plus:
    .word dict_minus
    .byte 2, "1+"
cfa_one_plus:
    .word code_one_plus
code_one_plus:
    inc PSP+0,x     ; increment lo
    bne :+          ; if no carry (non-zero result), we're done
    inc PSP+1,x     ; increment hi
:   jmp NEXT


; 1- ( n -- n-1 ) decrement by 1
dict_one_minus:
    .word dict_one_plus
    .byte 2, "1-"
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
dict_fetch:
    .word dict_one_minus
    .byte 1, "@"
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
dict_store:
    .word dict_fetch
    .byte 1, "!"
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
    .word dict_store
    .byte 3, "BYE"
cfa_bye:
    .word code_bye
code_bye:
    nop
    nop
    brk
    nop
    nop


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
    clc
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
    ; pop parameters off the stack
    ; pre-adjust ADDR by -2 so Y can index both strings simultaneously
    sec
    lda PSP+2,x     ; addr lo
    sbc #3
    sta ADDR
    lda PSP+3,x     ; addr hi
    sbc #0
    sta ADDR+1

    lda PSP+0,x     ; len
    sta LEN

    inx
    inx

    ; load LATEST into WX to start walking the dictionary
    lda LATEST
    sta WX
    lda LATEST+1
    sta WX+1

find_loop:
    ; if entry == 0, not found
    lda WX
    ora WX+1
    beq find_no_match

    ; check length byte (at offset 2 from entry)
    ldy #2
    lda (WX),y
    cmp LEN
    bne find_next       ; length mismatch, try next entry

    ; string compare - save X, use it as down-counter
    txa
    pha
    ldx LEN
    ldy #3              ; Y=3: first char of dict name; (ADDR),3 = first char of search string

find_cmp_loop:
    lda (WX),y
    cmp (ADDR),y
    bne find_cmp_fail
    iny
    dex
    bne find_cmp_loop

    ; full match - restore X, return CFA address (WX + 3 + LEN)
    pla
    tax
    clc
    lda WX
    adc #3
    sta WX
    bcc :+
    inc WX+1
:   clc
    lda WX
    adc LEN
    sta PSP+0,x
    lda WX+1
    adc #0
    sta PSP+1,x
    jmp NEXT

find_cmp_fail:
    pla
    tax
    ; fall through to find_next

find_next:
    ; follow the link field (at offset 0)
    ldy #0
    lda (WX),y
    pha
    iny
    lda (WX),y
    sta WX+1
    pla
    sta WX
    jmp find_loop

find_no_match:
    lda #0
    sta PSP+0,x
    sta PSP+1,x
    jmp NEXT


; BRANCH ( -- ) add an offset to IP
dict_branch:
    .word dict_find
    .byte 6, "BRANCH"
cfa_branch:
    .word code_branch
code_branch:
    ldy #$00
    lda (IP),y      ; load offset lo
    sta WX
    iny
    lda (IP),y      ; load offset hi
    sta WX+1

    ; advance IP past the offset cell first
    clc
    lda IP
    adc #2
    sta IP
    bcc :+
    inc IP+1
:

    ; now add the branch offset
    clc
    lda IP
    adc WX
    sta IP
    lda IP+1
    adc WX+1
    sta IP+1

    jmp NEXT


; 0BRANCH ( flag -- ) branch if flag is zero
dict_0branch:
    .word dict_branch
    .byte 7, "0BRANCH"
cfa_0branch:
    .word code_0branch
code_0branch:
    ; Pop the flag, and check if zero
    lda #$00
    ora PSP+0,x     ; apply TOS lo
    ora PSP+1,x     ; apply TOS hi
    inx
    inx
    cmp #$00        ; inx klobbered the Z flag, maybe

    bne :+
    ; Do the branch: WX = memory[IP], IP = IP + WX
    ldy #$00
    lda (IP),y      ; load offset lo
    sta WX
    iny
    lda (IP),y      ; load offset hi
    sta WX+1

    clc
    lda IP
    adc WX
    sta IP
    lda IP+1
    adc WX+1
    sta IP+1

    ; IP = IP + 2, regardless of whether we branched or not we gotta skip the offset
:   clc
    lda IP
    adc #2
    sta IP
    bcc :+
    inc IP+1

:   jmp NEXT


; = ( a b -- flag ) check if two values are equal
dict_equal:
    .word dict_0branch
    .byte 1, "="
cfa_equal:
    .word code_equal
code_equal:
    ; subtract the two values, using WX as a scratch area
    sec
    lda PSP+2,x     ; load NOS lo
    sbc PSP+0,x     ; subtract TOS lo
    sta WX          ; save lo result
    lda PSP+3,x     ; load NOS hi
    sbc PSP+1,x     ; subtract TOS hi
    sta WX+1        ; save hi result
    inx
    inx

    ; check for zero
    lda WX
    ora WX+1
    beq return_true
    jmp return_false


; Helper routine to put false on top of the stack and go next
return_false_with_pop:
    inx
    inx
return_false:
    lda #$00
    sta PSP+0,x
    sta PSP+1,x
    jmp NEXT

; Helper routine to put true on top of the stack and go next
return_true_with_pop:
    inx
    inx
return_true:
    lda #$FF
    sta PSP+0,x
    sta PSP+1,x
    jmp NEXT


; 0= ( a -- flag ) check if value is zero
dict_0equal:
    .word dict_equal
    .byte 2, "0="
cfa_0equal:
    .word code_0equal
code_0equal:
    ; OR the two bytes and check for zero
    lda PSP+0,x
    ora PSP+1,x
    beq return_true
    jmp return_false


; < ( a b -- flag ) check if a < b
dict_less_than:
    .word dict_0equal
    .byte 1, "<"
cfa_less_than:
    .word code_less_than
code_less_than:
    ; compare hi bytes first
    lda PSP+3,x     ; 'a' hi
    cmp PSP+1,x     ; 'b' hi
    beq :+

    ; hi bytes not equal, is it <?
    bcc return_true_with_pop    ; carry clear if a<b
    jmp return_false_with_pop

:   ; hi bytes equal, need to compare the lo bytes
    lda PSP+2,x     ; 'a' lo
    cmp PSP+0,x     ; 'b' lo
    beq return_false_with_pop

    ; lo bytes NOT equal, is it <?
    bcc return_true_with_pop    ; carry clear if a<b
    jmp return_false_with_pop


; > ( a b -- flag ) check if a > b
dict_greater_than:
    .word dict_less_than
    .byte 1, ">"
cfa_greater_than:
    .word DOCOL
    .word cfa_swap
    .word cfa_less_than
    .word cfa_exit


; Pointer to the first dictionary entry
LATEST:
    .word dict_greater_than



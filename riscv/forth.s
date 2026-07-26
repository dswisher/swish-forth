# forth.s - swish-forth kernel: RISC-V 32-bit, bare-metal
#
# Threading model: Indirect Threaded Code (ITC)
# See docs/step-01.md for design rationale.
#
# Platform-specific I/O (EMIT, KEY) and halt logic live in platform/*.s.
# This file contains only platform-independent kernel code.

    .include "forth.inc"

# -- BSS layout ----------------------------------------------------------------
#
# Memory layout (high to low):
#
#   rsp_top         <- RSP initialised here (return stack grows down)
#   rsp_buf         <- bottom of return stack
#   dsp_top         <- DSP initialised here (data stack grows down)
#   dsp_buf         <- bottom of data stack
#   _end            <- end of BSS / start of dictionary (managed by HERE)
#
# The linker provides the symbol _end at the end of BSS, which is where
# the dictionary will grow upward from in later steps.

    .bss

    .balign CELL
dsp_buf:
    .space DSTACK_SIZE
dsp_top:                        # DSP starts here (top of data stack buffer)

    .balign CELL
rsp_buf:
    .space RSTACK_SIZE
rsp_top:                        # RSP starts here (top of return stack buffer)

    .balign CELL
to_in_buf:
    .space CELL                 # Offset in characters from the start of the input buffer to the start of the parse area

    .balign CELL
source_len_buf:
    .space CELL                 # The number of characters currently in the input buffer

    .balign CELL
in_buf:
    .space IN_BUF_SIZE          # The input buffer

    .balign CELL
state_buf:
    .space CELL                 # The complation state: 0 = interpreting, non-zero = compiling


# -- DATA layout ---------------------------------------------------------------

    .section .data
    .balign CELL
here_buf:
    .word   _end

# NOTE - latest_buf is an exception, and lives at the bottom of the file


# -- Entry point ---------------------------------------------------------------

    .text
    .globl _start

_start:
    # Initialise the Forth data stack pointer (s3 = DSP).
    # DSP points to the top item; stack grows downward into dsp_buf.
    la      s3, dsp_top

    # Initialise the Forth return stack pointer (s2 = RSP).
    # RSP points to the top item; stack grows downward into rsp_buf.
    la      s2, rsp_top

    # -- test harness ----------------------------------------------------------
    # Test EMIT by using a pseudo-thread to invoke a "real" thread

_invoke:
    la      s0, invoke_thread
    NEXT

    .section .rodata
    .balign CELL
invoke_thread:
    .word   test_thread_cfa     # Run the test!
    .word   halt_word_cfa       # Stop the program


test_thread_cfa:
    .word   DOCOL_code

    .word   LIT_cfa
    .word   0x0000abcd

    .word   LIT_cfa
    .word   0x12341234
    .word   COMMA_cfa

    .word   REFILL_cfa          # Fill the input buffer

    .word   COLON_cfa

    # TODO - add DUP and + to definition

    .word   SEMI_cfa

    .word   EXIT_cfa

refill_test_str:
    .ascii  "DOUBLE"
refill_test_str_end:

.equ REFILL_TEST_LEN, refill_test_str_end - refill_test_str


# -- Halt thread ---------------------------------------------------------------
# A one-entry hand-threaded sequence used to cleanly terminate via NEXT.
# halt_thread contains a single CFA entry; halt_word_cfa's code field points
# to halt_code which is provided by the platform driver.

    .section .rodata
    .balign CELL
halt_thread:
    .word   halt_word_cfa

    .balign CELL
halt_word_cfa:
    .word   halt_code           # halt_code is defined in platform/*.s


# -- DOCOL ---------------------------------------------------------------------
    .text
DOCOL_code:
    # Push IP onto the return stack
    mv      t0, s0              # TMP = IP
    addi    s2, s2, -4          # RSP -= 4
    sw      t0, 0(s2)           # *RSP = TMP

    # W points to CFA, add 4 to point to the first cell
    addi    s0, s1, 4           # IP = W + 4

    NEXT


# -- EXIT ----------------------------------------------------------------------
#
# EXIT  ( -- )
# Return from a colon definition. Pops the saved IP from the return stack
# and resumes execution at that address.
#
# Return stack convention (full-descending):
#   Push: RSP -= CELL, then store
#   Pop:  load from RSP, then RSP += CELL

    defword "EXIT", EXIT, 0
    lw      s0, 0(s2)           # IP (s0) = *RSP - restore saved IP
    addi    s2, s2, 4           # RSP (s2) += CELL - pop return stack
    NEXT


# -- OVER ----------------------------------------------------------------------
#
# OVER  ( x1 x2 -- x1 x2 x1 )
# Place a copy of x1 on top of the stack.
#
# Before:  DSP+0 = x2 (top), DSP+4 = x1 (second)
# After:   DSP+0 = x1 (new top), DSP+4 = x2, DSP+8 = x1

    defword "OVER", OVER, EXIT_header
    lw      t0, 4(s3)           # TMP = x1 - load second item
    addi    s3, s3, -4          # DSP -= CELL - make room
    sw      t0, 0(s3)           # *DSP = x1 - push copy of second item
    NEXT


# -- DUP -----------------------------------------------------------------------
#
# DUP  ( x -- x x )
# Duplicate x.
#
# Before:  DSP+0 = x (top)
# After:   DSP+0 = x (new top), DSP+4 = x

    defword "DUP", DUP, OVER_header
    lw      t0, 0(s3)           # TMP = x - load item
    addi    s3, s3, -4          # DSP -= CELL - make room
    sw      t0, 0(s3)           # *DSP = x - push copy of item
    NEXT


# -- DROP ----------------------------------------------------------------------
#
# DROP  ( x -- )
# Remove x from the stack.

    defword "DROP", DROP, DUP_header
    addi    s3, s3, 4           # DSP += CELL - pop
    NEXT


# -- SWAP ----------------------------------------------------------------------
#
# SWAP  ( x1 x2 -- x2 x1 )
# Exchange the top two stack items.

    defword "SWAP", SWAP, DROP_header
    lw      t0, 0(s3)           # TMP0 = x2
    lw      t1, 4(s3)           # TMP1 = x1
    sw      t0, 4(s3)           # *DSP+4 = x2
    sw      t1, 0(s3)           # *DSP+0 = x1
    NEXT


# -- LIT -----------------------------------------------------------------------
# LIT ( -- x ) pushes the literal value in the next cell onto the stack

    defword "LIT", LIT, SWAP_header
    lw      t0, 0(s0)           # TMP = *IP
    addi    s3, s3, -4          # DSP -= CELL (push)
    sw      t0, 0(s3)           # *DSP = literal value
    addi    s0, s0, 4           # IP += 4
    NEXT


# -- BRANCH --------------------------------------------------------------------

    defword "BRANCH", BRANCH, LIT_header
    lw      t0, 0(s0)           # TMP = *IP
    add     s0, s0, t0          # IP = IP + TMP
    NEXT


# -- 0BRANCH -------------------------------------------------------------------

    defword "0BRANCH", ZERO_BRANCH, BRANCH_header
    lw      t0, 0(s3)           # TMP = x1 (flag)
    addi    s3, s3, 4           # DSP += CELL (pop)
    beqz    t0, bz_true
    addi    s0, s0, 4           # IP += 4
    j       bz_done
bz_true:
    lw      t0, 0(s0)           # TMP = *IP
    add     s0, s0, t0          # IP = IP + TMP
bz_done:
    NEXT


# -- EMIT ----------------------------------------------------------------------
#
# EMIT  ( char -- )
# Send the character on top of the data stack to the output device.
# Calls platform_putc, which is provided by files in platform/*.s

    defword "EMIT", EMIT, ZERO_BRANCH_header
    lw      a0, 0(s3)           # a0 = char
    addi    s3, s3, 4           # pop DSP
    call    platform_putc
    NEXT


# -- KEY -----------------------------------------------------------------------
#
# KEY  ( -- char )
# Read one character from the input device and push it onto the data stack.
# Calls platform_getc, which is provided by files in platform/*.s

    defword "KEY", KEY, EMIT_header
    call    platform_getc
    addi    s3, s3, -4          # push DSP
    sw      a0, 0(s3)           # *DSP = char
    NEXT


# -- >IN -----------------------------------------------------------------------
#
# >IN  ( -- a-addr )
# a-addr is the address of a cell containing the offset in characters from the
# start of the input buffer to the start of the parse area.

    defword ">IN", TO_IN, KEY_header
    addi    s3, s3, -4          # make room on the stack
    la      t0, to_in_buf       # push the >IN address
    sw      t0, 0(s3)
    NEXT


# -- SOURCE --------------------------------------------------------------------
#
# SOURCE  ( -- c-addr u )
# c-addr is the address of, and u is the number of characters in, the input
# buffer.

    defword "SOURCE", SOURCE, TO_IN_header
    addi    s3, s3, -8              # make room for two cells
    lw      t0, source_len_buf      # t0 = current length (u)
    la      t1, in_buf              # t1 = buffer address (c-addr)
    sw      t0, 0(s3)               # push u (top)
    sw      t1, 4(s3)               # push c-addr (second)
    NEXT


# -- REFILL --------------------------------------------------------------------
#
# REFILL  ( -- flag )
# Attempt to fill the input buffer from the input source, returning a true
# flag if successful.

    defword "REFILL", REFILL, SOURCE_header

    # Copy the test string into in_buf
    la      t0, refill_test_str     # source pointer
    la      t1, in_buf              # dest pointer
    li      t2, REFILL_TEST_LEN
refill_copy:
    lb      t3, 0(t0)               # load byte from source
    sb      t3, 0(t1)               # store byte to dest
    addi    t0, t0, 1
    addi    t1, t1, 1
    addi    t2, t2, -1
    bnez    t2, refill_copy

    # Set source_len
    la      t0, source_len_buf
    li      t1, REFILL_TEST_LEN
    sw      t1, 0(t0)

    # Set >IN to 0
    la      t0, to_in_buf
    sw      zero, 0(t0)

    # Push true flag
    addi    s3, s3, -4
    li      t0, -1                  # true = all bits set
    sw      t0, 0(s3)

    NEXT


# -- TYPE ----------------------------------------------------------------------
#
# TYPE  ( c-addr u -- )
# If u is greater than zero, display the character string specified by c-addr
# and u.

    defword "TYPE", TYPE, REFILL_header
    lw      t3, 0(s3)           # t3 = u (count)
    lw      t2, 4(s3)           # t2 = c-addr
    addi    s3, s3, 8           # pop both cells
type_loop:
    beqz    t3, type_done
    lb      a0, 0(t2)           # a0 = char (for platform_putc)
    addi    t2, t2, 1           # advance pointer
    addi    t3, t3, -1          # decrement count
    call    platform_putc       # clobbers t0, t1 only
    j       type_loop
type_done:
    NEXT


# -- PARSE-NAME ----------------------------------------------------------------
#
# PARSE-NAME  ( "<spaces>name<space>" -- c-addr u )
# Skip leading spaces, then parse a space-delimited token from the input
# buffer. Returns the address and length of the token within the buffer.
# Does not copy - c-addr points directly into in_buf.

    defword "PARSE-NAME", PARSE_NAME, TYPE_header

    # Load SOURCE: t0 = c-addr (in_buf), t1 = u (length)
    la      t0, in_buf
    lw      t1, source_len_buf

    # Load >IN offset and advance base pointer to parse area start
    lw      t2, to_in_buf           # t2 = >IN offset
    add     t0, t0, t2              # t0 = in_buf + >IN  (current position)
    sub     t1, t1, t2              # t1 = remaining characters

    # -- Phase 1: skip leading spaces ------------------------------------------
parse_name_skip:
    beqz    t1, parse_name_empty    # exhausted buffer
    lb      t3, 0(t0)               # t3 = current char
    li      t4, ' '
    bne     t3, t4, parse_name_start # non-space: token starts here
    addi    t0, t0, 1               # advance pointer
    addi    t1, t1, -1              # decrement remaining
    j       parse_name_skip

    # -- Phase 2: record token start, scan for end -----------------------------
parse_name_start:
    mv      t4, t0                  # t4 = c-addr (start of token)
    li      t5, 0                   # t5 = token length
parse_name_scan:
    beqz    t1, parse_name_done     # end of buffer: token ends here
    lb      t3, 0(t0)               # t3 = current char
    li      t6, ' '
    beq     t3, t6, parse_name_done # space: token ends here
    addi    t0, t0, 1               # advance pointer
    addi    t1, t1, -1              # decrement remaining
    addi    t5, t5, 1               # increment token length
    j       parse_name_scan

    # -- Update >IN ------------------------------------------------------------
parse_name_done:
    # t0 now points just past the token (or at the trailing space).
    # Advance one more if we stopped on a space (consume the delimiter).
    beqz    t1, parse_name_update   # no chars left, don't advance
    addi    t0, t0, 1               # skip the trailing space
parse_name_update:
    la      t3, in_buf
    sub     t3, t0, t3              # new >IN = current pos - in_buf base
    la      t6, to_in_buf
    sw      t3, 0(t6)               # store new >IN

    # -- Push ( c-addr u ) -----------------------------------------------------
    addi    s3, s3, -8
    sw      t4, 4(s3)               # push c-addr
    sw      t5, 0(s3)               # push u (top)
    NEXT

    # -- Empty parse area: return ( c-addr 0 ) ---------------------------------
parse_name_empty:
    la      t0, in_buf
    li      t5, 0
    j       parse_name_update


# -- HERE ----------------------------------------------------------------------
#
# HERE  ( -- addr )
# addr is the data-space pointer.

    defword "HERE", HERE, PARSE_NAME_header
    addi    s3, s3, -4          # make room on the stack
    la      t0, here_buf        # push the HERE address
    sw      t0, 0(s3)
    NEXT


# -- LATEST --------------------------------------------------------------------
#
# LATEST  ( -- addr )
# addr is the LATEST pointer.

    defword "LATEST", LATEST, HERE_header
    addi    s3, s3, -4          # make room on the stack
    la      t0, latest_buf      # push the LATEST address
    sw      t0, 0(s3)
    NEXT


# -- STATE ---------------------------------------------------------------------
#
# STATE  ( -- addr )
# addr is the STATE pointer.

    defword "STATE", STATE, LATEST_header
    addi    s3, s3, -4          # make room on the stack
    la      t0, state_buf       # push the STATE address
    sw      t0, 0(s3)
    NEXT


# -- STORE ---------------------------------------------------------------------
#
# !  ( x a-addr -- )
# Store x at a-addr.

    defword "!", STORE, STATE_header
    lw      t0, 0(s3)           # TMP1 = a-addr
    addi    s3, s3, 4           # pop
    lw      t1, 0(s3)           # TMP2 = x
    addi    s3, s3, 4           # pop
    sw      t1, 0(t0)           # *addr = x
    NEXT


# -- FETCH ---------------------------------------------------------------------
#
# @  ( a-addr -- x )
# x is the value stored at a-addr.

    defword "@", FETCH, STORE_header
    lw      t0, 0(s3)           # TMP1 = addr
    lw      t1, 0(t0)           # TMP2 = *addr
    sw      t1, 0(s3)           # stack = x
    NEXT


# -- PLUS ----------------------------------------------------------------------
#
# +  ( x1 x2 -- x3 )
# Add x1 and x2 giving the sum x3

    defword "+", PLUS, FETCH_header
    lw      t0, 0(s3)           # TMP1 = x2
    addi    s3, s3, 4           # pop
    lw      t1, 0(s3)           # TMP2 = x1
    add     t0, t0, t1          # TMP1 = TMP1 + TMP2
    sw      t0, 0(s3)           # stack = result
    NEXT


# -- MINUS ---------------------------------------------------------------------
#
# -  ( x1 x2 -- x3 )
# Subtract x2 from x1 giving the difference x3 (x1 - x2)

    defword "-", MINUS, PLUS_header
    lw      t0, 0(s3)           # TMP1 = x2
    addi    s3, s3, 4           # pop
    lw      t1, 0(s3)           # TMP2 = x1
    sub     t0, t1, t0          # TMP1 = x1 - x2
    sw      t0, 0(s3)           # stack = result
    NEXT


# -- AND -----------------------------------------------------------------------
#
# AND  ( x1 x2 -- x3 )
# x3 is the bit-by-bit logical "and" of x1 with x2.

    defword "AND", AND, MINUS_header
    lw      t0, 0(s3)           # TMP1 = x2
    addi    s3, s3, 4           # pop
    lw      t1, 0(s3)           # TMP2 = x1
    and     t0, t1, t0          # TMP1 = x1 & x2
    sw      t0, 0(s3)           # stack = result
    NEXT


# -- C@ ------------------------------------------------------------------------
#
# C@  ( c-addr -- char )
# Fetch the character stored at c-addr.

    defword "C@", CFETCH, AND_header
    lw      t0, 0(s3)           # TMP1 = addr
    lbu     t1, 0(t0)           # TMP2 = *addr
    sw      t1, 0(s3)           # stack = TMP2
    NEXT


# -- C! ------------------------------------------------------------------------
#
# C!  ( char c-addr -- )
# Store char at c-addr.

    defword "C!", CSTORE, CFETCH_header
    lw      t0, 0(s3)           # TMP1 = a-addr
    addi    s3, s3, 4           # pop
    lw      t1, 0(s3)           # TMP2 = x
    addi    s3, s3, 4           # pop
    sb      t1, 0(t0)           # *addr = x
    NEXT


# -- C, ------------------------------------------------------------------------
#
# C,  ( char -- )
# Reserve space for one character in the data space and store char in the space.

    defcolon "C,", CCOMMA, CSTORE_header
    .word   HERE_cfa            # HERE          ( char HERE )
    .word   FETCH_cfa           # @             ( char H )
    .word   CSTORE_cfa          # C!            ( )
    .word   HERE_cfa            # HERE          ( HERE )
    .word   FETCH_cfa           # @             ( H )
    .word   LIT_cfa             # 1             ( H 1 )
    .word   1
    .word   PLUS_cfa            # +             ( H+1 )
    .word   HERE_cfa            # HERE          ( H+1 HERE )
    .word   STORE_cfa           # !             ( )
    .word   EXIT_cfa


# -- R> ------------------------------------------------------------------------
#
# R>  ( -- x ) ( R: x -- )
# Move x from the return stack to the data stack.

    defword "R>", RFROM, CCOMMA_header
    lw      t0, 0(s2)           # TMP = *RSP
    addi    s2, s2, 4           # RSP += CELL
    addi    s3, s3, -4          # DSP -= CELL
    sw      t0, 0(s3)           # *DSP = x
    NEXT


# -- >R ------------------------------------------------------------------------
#
# >R  ( x -- ) ( R: -- x )
# Move x to the return stack.

    defword ">R", RTO, RFROM_header
    lw      t0, 0(s3)           # TMP = *SSP
    addi    s3, s3, 4           # DSP += CELL
    addi    s2, s2, -4          # RSP -= CELL
    sw      t0, 0(s2)           # *RSP = x
    NEXT


# -- 0= ------------------------------------------------------------------------
#
# 0=  ( x -- flag )
# flag is true if and only if x is equal to zero.

defword "0=", ZERO_EQ, RTO_header
    lw      t0, 0(s3)       # load top of stack
    seqz    t0, t0          # t0 = 1 if t0==0, else 0
    neg     t0, t0          # convert to Forth true (-1) or false (0)
    sw      t0, 0(s3)       # store result
    NEXT


# -- COMMA ---------------------------------------------------------------------
#
# ,  ( x -- )
# Reserve one cell of data space and store x in the cell.

    defcolon ",", COMMA, ZERO_EQ_header
    .word   HERE_cfa            # HERE          ( n HERE )
    .word   FETCH_cfa           # @             ( n H )
    .word   STORE_cfa           # !             ( )
    .word   HERE_cfa            # HERE          ( HERE )
    .word   FETCH_cfa           # @             ( H )
    .word   LIT_cfa             # 4             ( H 4 )
    .word   4
    .word   PLUS_cfa            # +             ( H+4 )
    .word   HERE_cfa            # HERE          ( H+4 HERE )
    .word   STORE_cfa           # !             ( )
    .word   EXIT_cfa


# -- CREATE --------------------------------------------------------------------
#
# CREATE  ( "<spaces>name" -- )
# Skip leading space delimiters. Parse name delimited by a space. Create a
# definition for name with the execution semantics defined below.

    defcolon "CREATE", CREATE, COMMA_header
    .word   PARSE_NAME_cfa      # PARSE-NAME              ( c-addr u )
    .word   HERE_cfa
    .word   FETCH_cfa           # HERE @                  ( c-addr u hdr )
    .word   LATEST_cfa
    .word   FETCH_cfa
    .word   COMMA_cfa           # LATEST @ ,              ( c-addr u hdr )    \ step 2: write link
    .word   OVER_cfa
    .word   CCOMMA_cfa          # OVER C,                 ( c-addr u hdr )    \ step 3a: write length
    .word   RTO_cfa             # >R                      ( c-addr u )        \ park hdr on return stack

    # \ step 3b: loop — ( c-addr u )
    # <loop-top>:

    .word   DUP_cfa
    .word   ZERO_EQ_cfa
    .word   ZERO_BRANCH_cfa     # DUP 0= 0BRANCH <loop-body>
    .word   12

    .word   BRANCH_cfa          # BRANCH <loop-done>
    .word   56

    # <loop-body>:
    .word   OVER_cfa
    .word   CFETCH_cfa          #   OVER C@               ( c-addr u char )   \ fetch next char
    .word   CCOMMA_cfa          #   C,                    ( c-addr u )        \ append to HERE
    .word   SWAP_cfa
    .word   LIT_cfa
    .word   1
    .word   PLUS_cfa
    .word   SWAP_cfa            #   SWAP LIT 1 + SWAP     ( c-addr+1 u )      \ advance pointer
    .word   LIT_cfa
    .word   1
    .word   MINUS_cfa           #   LIT 1 -               ( c-addr+1 u-1 )    \ decrement count
    .word   BRANCH_cfa          #   BRANCH <loop-top>
    .word   -72

    # <loop-done>:
    .word   DROP_cfa
    .word   DROP_cfa            #   DROP DROP             ( )                 \ drop count and pointer
    .word   RFROM_cfa           #   R>                    ( hdr )             \ retrieve saved header address

    # \ step 4: pad HERE to 4-byte boundary
    .word   HERE_cfa
    .word   FETCH_cfa
    .word   LIT_cfa
    .word   3
    .word   PLUS_cfa
    .word   LIT_cfa
    .word   -4
    .word   AND_cfa
    .word   HERE_cfa
    .word   STORE_cfa           # HERE LIT 3 + LIT -4 AND HERE !

    # \ step 5: update LATEST
    .word   LATEST_cfa
    .word   STORE_cfa           # LATEST !

    .word   EXIT_cfa


# -- : -------------------------------------------------------------------------
#
# :  ( "<spaces>name" -- )
# Skip leading space delimiters. Parse name delimited by a space. Create a
# definition for name, called a "colon definition". Enter compilation state
# and start the current definition, producing colon-sys.

    defcolon ":", COLON, CREATE_header
    .word   CREATE_cfa          # CREATE
    .word   LIT_cfa
    .word   DOCOL_code          # address of DOCOL
    .word   COMMA_cfa           # ,                         \ save DOCOL as CFA

    .word   LIT_cfa
    .word   -1
    .word   STATE_cfa
    .word   STORE_cfa           # -1 STATE !                \ set STATE to compiling

    .word   EXIT_cfa


# -- ; -------------------------------------------------------------------------
#
# ;  ( "<spaces>name" -- )
# Skip leading space delimiters. Parse name delimited by a space. Create a
# definition for name, called a "colon definition". Enter compilation state
# and start the current definition, producing colon-sys.

    defcolon ";", SEMI, COLON_header
    .word   LIT_cfa
    .word   EXIT_cfa            # addres of EXIT CFA
    .word   COMMA_cfa           # ,

    .word   LIT_cfa
    .word   0
    .word   STATE_cfa
    .word   STORE_cfa           # 0 STATE !                 \ set STATE to interpreting

    .word   EXIT_cfa


# -- latest_buf ----------------------------------------------------------------
# A pointer to the last dictionary entry.
# NOTE - add new dictionary entries ABOVE this

    .section .data
    .balign CELL
latest_buf:                     # points to the last defword in the chain
    .word   SEMI_header


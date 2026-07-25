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

    .word   REFILL_cfa      # fill the buffer with goodness
    .word   DROP_cfa        # drop the true flag

    .word   PARSE_NAME_cfa  # parse HELLO
    .word   DROP_cfa        # ...and drop it
    .word   DROP_cfa

    .word   PARSE_NAME_cfa  # parse WORLD
    .word   DROP_cfa        # ...and drop it
    .word   DROP_cfa

    .word   PARSE_NAME_cfa  # try to parse again -> success should be false

    .word   EXIT_cfa

refill_test_str:
    .ascii  "HELLO WORLD"
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

    defword "0BRANCH", ZBRANCH, BRANCH_header
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

    defword "EMIT", EMIT, ZBRANCH_header
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


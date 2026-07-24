# forth.s - swish-forth kernel: RISC-V 32-bit, Linux userspace
#
# Threading model: Indirect Threaded Code (ITC)
# See docs/step-01.md for design rationale.

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
emit_buf:
    .space 1                    # scratch byte for EMIT/KEY


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

    la      s0, invoke_thread
    NEXT

    .section .rodata
    .balign CELL
invoke_thread:
    .word   test_thread_cfa     # Run the test!
    .word   halt_word_cfa       # Stop the program


test_thread_cfa:
    .word   DOCOL_code
    .word   LIT_cfa             # LIT
    .word   33                  # Decimal value for !
    .word   EMIT_cfa
    .word   NOP_cfa             # Handy place to set a breakpoint
    .word   EXIT_cfa


# -- Halt thread ---------------------------------------------------------------
# A one-entry hand-threaded sequence used to cleanly terminate via NEXT.
# halt_thread contains a single CFA entry; halt_word_cfa's code field points
# to halt_code which calls exit(0).

    .section .rodata
    .balign CELL
halt_thread:
    .word   halt_word_cfa

    .balign CELL
halt_word_cfa:
    .word   halt_code

    .text
    .balign CELL
halt_code:
    li      a7, 93
    li      a0, 0
    ecall


# -- DOCOL ---------------------------------------------------------------------
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
    sw      t0, 0(s3)           # *DSP = a - push copy of item
    addi    s0, s0, 4           # IP += 4
    NEXT


# -- BRANCH --------------------------------------------------------------------
#

    defword "BRANCH", BRANCH, LIT_header
    lw      t0, 0(s0)           # TMP = *IP
    add     s0, s0, t0          # IP = IP + TMP
    NEXT


# -- 0BRANCH -------------------------------------------------------------------
#

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
# EMIT  ( x -- )
# If x is a graphic character in the implementation-defined character set, display x. 

    defword "EMIT", EMIT, ZBRANCH_header
    # Pop item off the stack and store 1 byte into the buffer
    lw      t0, 0(s3)           # TMP = char
    addi    s3, s3, 4           # pop DSP
    la      t1, emit_buf        # buffer address
    sb      t0, 0(t1)           # store low byte to emit_buf

    # Make the call to write a character
    li      a7, 64              # SYS_write
    li      a0, 1               # stdout
    mv      a1, t1              # buffer address in a1 (copied from t1)
    li      a2, 1               # length, I assume?
    ecall

    NEXT


# -- NOP -----------------------------------------------------------------------
# TODO - this is a temporary debugging word - remove it once assembly-level debugging is done
#
    defword "NOP", NOP, EMIT_header
    nop
    NEXT


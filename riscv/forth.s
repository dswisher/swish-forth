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
    # Hand-threaded sequence to exercise LIT, 0BRANCH, and BRANCH.
    #
    # The thread below does the following:
    #   LIT 0        -- push 0 (false)
    #   0BRANCH +8   -- branch taken (0 is false); skips the next 2 cells
    #   LIT 99       -- skipped
    #   LIT 42       -- lands here; push 42
    #   LIT 1        -- push 1 (true)
    #   0BRANCH +4   -- branch NOT taken (1 is true); skip 1 cell
    #   LIT 77       -- skipped
    #   BRANCH -24   -- unconditional branch back to "LIT 42" cell
    #                   (offset is relative to the offset cell itself;
    #                    -24 steps back over: offset cell, LIT 77 cfa,
    #                    0BRANCH cfa, LIT 1 value, LIT 1 cfa, LIT 42 value,
    #                    LIT 42 cfa = 6 cells = 24 bytes)
    #
    # In GDB, set a breakpoint on LITERAL_code and ZBRANCH_code and watch
    # IP and the stack to verify each step.
    #
    # The BRANCH creates an infinite loop intentionally - hit the breakpoint
    # a couple of times then quit.

    la      s0, test_thread
    NEXT

    .section .rodata
    .balign CELL
test_thread:
    .word   LIT_cfa             # LIT
    .word   0                   # value: 0 (false)
    .word   ZBRANCH_cfa         # 0BRANCH
    .word   12                  # offset: +4; NEXT adds 4 = skip 2 cells (LIT 99), land on NOP
    .word   LIT_cfa             # LIT  <-- skipped when branch taken
    .word   99                  # value: 99

    .word   NOP_cfa             # debug hack    <-- branch target (for now)

    .word   LIT_cfa             # LIT  <-- branch target
    .word   42                  # value: 42
    .word   LIT_cfa             # LIT
    .word   1                   # value: 1 (true)
    .word   ZBRANCH_cfa         # 0BRANCH
    .word   4                   # offset: +4; NEXT adds 4 = skip 2 cells (LIT 77)
    .word   LIT_cfa             # LIT  <-- skipped when branch not taken
    .word   77                  # value: 77
    .word   BRANCH_cfa          # BRANCH
    .word   -24                 # offset: -24; NEXT adds 4 = back 5 cells to LIT 42

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

# -- NOP -----------------------------------------------------------------------
# TODO - this is a temporary debugging word - remove it once assembly-level debugging is done
#
    defword "NOP", NOP, ZBRANCH_header
    nop
    NEXT


# forth.s - swish-forth kernel: RISC-V 32-bit, Linux userspace
#
# Threading model: Indirect Threaded Code (ITC)
# See docs/step-01.md for design rationale.

    .include "forth.inc"

# ── BSS layout ────────────────────────────────────────────────────────────────
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

# ── Entry point ───────────────────────────────────────────────────────────────

    .text
    .globl _start

_start:
    # Step 1: nothing to execute yet.
    # Subsequent steps will initialise DSP, RSP, and launch the interpreter.

    # exit(0)
    li      a7, 93
    li      a0, 0
    ecall

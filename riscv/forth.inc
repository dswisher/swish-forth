# forth.inc - Register assignments and memory layout constants
#
# Threading model: Indirect Threaded Code (ITC)
#
# In ITC, every word has a Code Field Address (CFA) containing a pointer
# to a machine-code routine. NEXT loads the CFA into W, then jumps to
# the address that W points to.

# ── Register assignments ───────────────────────────────────────────────────────
#
# We use the s (saved) registers so these are preserved across any C calls.

#   IP  - Instruction Pointer: address of the next word's CFA in the thread
#   W   - Working register: address of the current word's CFA
#   RSP - Return Stack Pointer: Forth return stack (separate from sp)
#   DSP - Data Stack Pointer: Forth parameter stack
#   TMP - Scratch register for use inside primitives

.equ IP,  s0
.equ W,   s1
.equ RSP, s2
.equ DSP, s3
.equ TMP, s4

# ── Cell size ─────────────────────────────────────────────────────────────────

.equ CELL, 4                    # 32-bit architecture: one cell = 4 bytes

# ── Stack sizes ───────────────────────────────────────────────────────────────

.equ DSTACK_SIZE, 0x10000       # 64KB data stack (~16K cells)
.equ RSTACK_SIZE, 0x10000       # 64KB return stack (~16K cells)

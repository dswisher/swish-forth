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
# These are conventions only; the assembler uses the real register names below.
#
#   s0  (IP)  - Instruction Pointer: address of the next word's CFA in the thread
#   s1  (W)   - Working register: address of the current word's CFA
#   s2  (RSP) - Return Stack Pointer: Forth return stack (separate from sp)
#   s3  (DSP) - Data Stack Pointer: Forth parameter stack
#   s4  (TMP) - Scratch register for use inside primitives

# ── Cell size ─────────────────────────────────────────────────────────────────

.equ CELL, 4                    # 32-bit architecture: one cell = 4 bytes

# ── Stack sizes ───────────────────────────────────────────────────────────────

.equ DSTACK_SIZE, 0x10000       # 64KB data stack (~16K cells)
.equ RSTACK_SIZE, 0x10000       # 64KB return stack (~16K cells)

# ── NEXT macro ────────────────────────────────────────────────────────────────
#
# NEXT is the inner interpreter. It is not a Forth word but a macro expanded
# inline at the end of every primitive.
#
# In ITC, a thread is a sequence of CFAs (Code Field Addresses). Each CFA
# points to the machine-code routine for that word. NEXT fetches the next
# CFA from the thread, advances IP, then jumps to the code the CFA points to.
#
# Step by step:
#   1. W = *IP        fetch the CFA of the next word from the thread
#   2. IP += CELL     advance IP past the CFA we just fetched
#   3. TMP = *W       fetch the code pointer from the code field
#   4. jump to TMP    execute the code

.macro NEXT
    lw      s1, 0(s0)           # W (s1) = *IP  — fetch next CFA
    addi    s0, s0, 4           # IP (s0) += CELL — advance IP
    lw      s4, 0(s1)           # TMP (s4) = *W  — fetch code pointer
    jr      s4                  # jump to code
.endm

# ── defword macro ─────────────────────────────────────────────────────────────
#
# defword creates a dictionary entry header for a primitive word.
#
# Each dictionary entry has this layout:
#
#   link    (4 bytes) - pointer to previous entry (0 for the first word)
#   flags   (1 byte)  - name length in lower 5 bits; upper bits reserved
#   name    (n bytes) - ASCII characters, not null-terminated
#   padding           - to align the CFA to a 4-byte boundary
#   CFA     (4 bytes) - code field: address of the code routine (label below)
#
# Arguments:
#   name    - the Forth name as a quoted string (e.g. "EXIT")
#   label   - the assembly label used to refer to this word (e.g. EXIT)
#   link    - the label of the previous word's header (0 for the first word)
#
# Usage:
#   defword "EXIT", EXIT, 0
#   EXIT_code:
#       ... implementation ...
#       NEXT

.macro defword name, label, link
    .section .rodata
    .balign CELL
\label\()_header:
    .word   \link               # link to previous word
    .byte   (.Lname_end_\label - .Lname_start_\label)  # name length
.Lname_start_\label:
    .ascii  "\name"             # name characters
.Lname_end_\label:
    .balign CELL                # pad to cell alignment
\label\()_cfa:
    .word   \label\()_code      # code field: points to the code label
    .text                       # return to .text for the code body
    .balign CELL
\label\()_code:                 # code label follows immediately in .text
.endm

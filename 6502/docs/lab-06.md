# Lab 6: LIT, the Dictionary, and FIND

## Objectives

- Implement `LIT` - the primitive that pushes inline literals from the thread
- Understand the structure of a FORTH dictionary entry
- Build a static dictionary of the words implemented so far
- Implement `FIND` - the primitive that searches the dictionary by name

## Prerequisites

- Lab 5 complete - all stack, arithmetic, and memory primitives working
- Comfortable with the zero-page layout and ITC dispatch mechanism

---

## Background

### LIT - Inline Literals

So far, test values have been hand-loaded onto the stack in `main` before
entering the interpreter. That works for testing but is not how FORTH actually
works. In a real FORTH program, numbers appear inline in colon definitions:

```forth
: DOUBLE   2 * ;
```

When the compiler sees `2`, it does not push 2 at compile time - it emits
two cells into the definition's body: a pointer to `LIT`, followed by the
value `2`. At run time, when `NEXT` dispatches `LIT`, the code reads the next
cell from the thread (via `IP`), pushes it onto the stack, advances `IP` past
it, and calls `NEXT` again.

In pseudocode:

```
LIT:
    push memory[IP]     ; fetch the inline value and push it
    IP = IP + 2         ; skip past the inline value
    NEXT
```

In the thread, a literal looks like this:

```asm
.word cfa_lit       ; call LIT
.word $0042         ; the value to push (lo byte first, then hi)
```

`LIT` is a primitive - its CFA points to its own code. After implementing it,
you can replace the manual stack setup in `main` with a proper test thread that
pushes its own values.

### The Dictionary

Every FORTH word has a **dictionary entry** that records its name and links it
to its CFA. The outer interpreter uses the dictionary to look up words by name.
Without a dictionary, FORTH is just a collection of machine code routines with
no way to find them by name at run time.

A classic FORTH dictionary entry has this layout:

```
+------------------+
| Link field       |  2 bytes - pointer to previous entry (or 0)
+------------------+
| Name field       |  1 byte length, then the name characters
+------------------+
| CFA              |  2 bytes - the code field address
+------------------+
| PFA (body)       |  variable length - for colon defs, list of CFAs
+------------------+
```

The entries are chained together in a linked list. The most recently defined
word is at the head; searching walks backward toward the oldest word. A global
label `LATEST` points to the most recent entry.

#### The Link Field

The link field contains the address of the **previous entry's name field** (or
0 for the first word in the dictionary). `FIND` uses this to walk the chain.

#### The Name Field

The name field starts with a **1-byte count** of the number of characters,
followed by the characters themselves (not null-terminated). For example, the
word `DUP` has a name field of:

```asm
.byte 3, "DUP"
```

In many classic FORTH implementations, the high bit of the length byte is used
as a flag (the "smudge" bit or "immediate" bit). We will keep it simple for now
and use the length byte as a plain count.

#### Putting It Together

Here is what a complete dictionary entry for `DUP` looks like in assembly:

```asm
; Dictionary entry for DUP
dict_dup:
    .word dict_drop     ; link to previous entry
    .byte 3, "DUP"      ; name field: length + characters
cfa_dup:
    .word code_dup      ; CFA: points to machine code
code_dup:
    lda PSP+0,x
    ldy PSP+1,x
    dex
    dex
    sta PSP+0,x
    tya
    sta PSP+1,x
    NEXT
```

Notice that `cfa_dup` is now directly after the name field - the dictionary
entry and the word's CFA are part of the same structure. This is the standard
layout; `FIND` returns the CFA address, which is what `NEXT` needs.

#### LATEST

A label `LATEST` points to the most recently defined word's dictionary entry.
As you define words, `LATEST` is updated. For a static dictionary assembled at
compile time, `LATEST` is simply the label of the last entry:

```asm
LATEST: .word dict_store    ; points to the most recent entry
```

### FIND

`FIND` ( addr len -- cfa | 0 ) takes a string address and length from the
stack, searches the dictionary, and returns either the CFA of the matching word
or 0 if not found.

The algorithm:

```
entry = memory[LATEST]      ; start at the most recent entry
while entry != 0:
    name_len = memory[entry + 2]        ; length byte of this entry
    if name_len == len:
        if memory[entry + 3 .. entry + 3 + len] == string:
            return entry + 3 + len      ; CFA is right after the name
    entry = memory[entry]               ; follow the link
return 0                                ; not found
```

`FIND` is one of the more complex primitives you will write - it involves
a loop, pointer arithmetic, and a string comparison. Take it one step at a
time.

---

## The Assignment

Continue working in a new `lab-06/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-05/` as a starting point.

### Part 1 - Implement LIT

Add `LIT` as a primitive. Its CFA points to its own code, like any primitive.
The code must:

1. Load the 16-bit value at `IP` (lo byte first, hi byte second)
2. Push it onto the parameter stack
3. Advance `IP` by 2 (past the inline value)
4. Call `NEXT`

Once `LIT` is working, update `main` to remove the manual stack pushes and
replace the test thread with one that uses `LIT` to push its own values:

```asm
main:
    ldx #$FF
    lda #<test_thread
    sta IP
    lda #>test_thread
    sta IP+1
    NEXT

test_thread:
    .word cfa_lit, 3    ; push 3
    .word cfa_lit, 5    ; push 5
    .word cfa_plus      ; add -> 8
    .word cfa_exit
```

Verify in the debugger that after executing the thread, the stack contains
a single value of 8.

> **Note**: `.word cfa_lit, 3` emits two 2-byte cells: the address of
> `cfa_lit`, followed by the value 3 (as a 16-bit little-endian word). That
> is exactly what `LIT` expects to find at `IP`.

### Part 2 - Add Dictionary Entries

Restructure `forth.asm` so that each word has a dictionary entry immediately
before its CFA. The link fields chain the entries together.

Define entries for all the words implemented so far:

- `EXIT`
- `DUP`, `DROP`, `SWAP`, `OVER`
- `+`, `-`, `1+`, `1-`
- `@`, `!`
- `LIT`

The order matters: the link field of each entry points to the entry defined
immediately before it. The first entry (your choice which word comes first)
has a link field of 0.

Add a `LATEST` label after the last entry, pointing to the most recent one.

> **Note on names**: Some FORTH word names contain characters that are awkward
> in assembly label names. Use a consistent convention for the dictionary name
> fields: `+` is stored as the single character `+`, `1+` as the two
> characters `1+`, etc. The label names in assembly (`cfa_plus`, `cfa_one_plus`)
> are separate from the FORTH names stored in the name fields.

### Part 3 - Implement FIND

Add `FIND` as a primitive. It takes a string address and length from the stack
and returns the CFA address of the matching word, or 0 if not found.

Work through the algorithm from the background section. You will need:
- A zero-page pointer to walk the dictionary (consider using `W` or a new
  scratch register)
- A loop that fetches the link field to advance to the next entry
- A length check before doing the full string comparison
- A byte-by-byte string comparison inner loop

This is the most complex primitive so far. Break it into pieces and test
each one.

### Part 4 - Test FIND

Write a test thread that:

1. Uses `LIT` to push the address and length of a known word name onto the
   stack
2. Calls `FIND`
3. Leaves the result on the stack for inspection in the debugger

For example, to search for `DUP`:

```asm
str_dup:
    .byte "DUP"

test_thread:
    .word cfa_lit, str_dup      ; push address of "DUP"
    .word cfa_lit, 3            ; push length 3
    .word cfa_find              ; search -> should return cfa_dup
    .word cfa_exit
```

Verify in the debugger that the result on the stack is the address of `cfa_dup`.
Also test with a name that does not exist in the dictionary and verify that 0
is returned.

---

## Questions to Think About

1. `LIT` advances `IP` by 2 after reading the inline value. What would happen
   if `LIT` forgot to advance `IP`? What would the inner interpreter do next?

2. The dictionary entries are laid out in assembly in a fixed order. In a real
   FORTH system, new words can be defined at run time and added to the
   dictionary. How would that work? Where in memory would new entries go?

3. `FIND` does a linear search through the dictionary. For a small dictionary
   this is fine, but it slows down as the dictionary grows. What data
   structures could speed up the search? (This is a preview of a possible
   future optimization - no need to implement it now.)

4. The name field uses a plain length byte with no flags. ANS FORTH uses the
   high bit of the length byte as an "immediate" flag, marking words that
   execute at compile time rather than run time. Where in `FIND` would you
   need to mask off that bit to avoid breaking name comparisons?

5. `FIND` returns the CFA on success and 0 on failure. Some FORTH
   implementations return different values to distinguish "found and immediate"
   from "found and not immediate". How would that change the interface?

---

## Stretch Goals

- **FIND with smudge bit**: Add a "smudge" flag (bit 6 of the length byte)
  that hides a word from `FIND` while it is being defined. This prevents
  recursive lookups of partially-defined words. How does this interact with
  the length comparison in `FIND`?
- **Counted strings**: In FORTH, a **counted string** is a length byte
  followed by characters - exactly the format of the name field. Add a helper
  routine `SCOUNT` ( cstr -- addr len ) that takes a counted string address
  and returns the address of the first character and the length. This makes
  it easier to pass names to `FIND`.
- **WORDS**: Implement a word `WORDS` that walks the dictionary and prints
  every word name. This requires I/O (the X16 `CHROUT` routine from Lab 1),
  but is extremely useful for debugging. It also gives you a first taste of
  a word implemented in terms of `FIND`'s dictionary-walking machinery.

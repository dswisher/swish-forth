# Lab 9: The Compiler

## Objectives

- Implement `HERE` and `,` (COMMA) - the dictionary allocation primitives
- Implement `STATE` - the compile/interpret mode flag
- Implement `:` and `;` - the colon compiler
- Extend `INTERPRET` to compile words when in compile mode
- Understand immediate words and why `;` must be one

## Prerequisites

- Lab 8 complete - the outer interpreter running interactively
- Understanding of how the dictionary is laid out in memory (link, length,
  name, CFA, PFA)
- Familiarity with `DOCOL` and `EXIT` - the colon definition entry and exit

---

## Background

### What the Compiler Does

Up to now, every word in the dictionary was hand-compiled in assembly using
`.word` directives. The FORTH compiler automates exactly this: `:` creates a
new dictionary entry and switches to compile mode; `INTERPRET` then compiles
each subsequent word (appending its CFA to the thread) rather than executing
it; `;` appends `EXIT` and switches back to interpret mode.

The result is a new colon definition built dynamically in memory, identical in
structure to the hand-compiled ones from earlier labs.

### HERE and the Dictionary Pointer

The dictionary grows upward in memory. You need a pointer to the next free
location - traditionally called `HERE`. In this implementation, `HERE` will
be a 2-byte variable in memory (not zero page). The word `HERE` ( -- addr )
pushes the *value* of that pointer (the address where the next byte will be
written).

Two companion words build on `HERE`:

- `ALLOT` ( n -- ) advances `HERE` by n bytes, reserving space without
  writing anything
- `,` (COMMA) ( n -- ) writes a 16-bit cell at `HERE` and advances it by 2

These three words are sufficient to build the compiler.

### STATE

`STATE` is a 2-byte variable in memory. When zero, the interpreter is in
**interpret mode** (the default). When non-zero, it is in **compile mode**.

`:` sets `STATE` to a non-zero value; `;` resets it to zero.

`INTERPRET` checks `STATE` after each successful `FIND`: if in interpret
mode, it calls `EXECUTE`; if in compile mode, it calls `,` to append the CFA
to the current definition.

### The Colon Compiler

`:` does the following:

1. Call `WORD` to read the new word's name
2. Build a dictionary entry in memory:
   - Write the link field (2 bytes): current value of `LATEST`
   - Write the length byte and name characters
   - Write the CFA: a 2-byte pointer to `DOCOL`
3. Update `LATEST` to point to the new entry
4. Set `STATE` to compile mode

`;` does the following (and must be **immediate** - see below):

1. Compile `EXIT` (append `cfa_exit` to the thread)
2. Set `STATE` back to zero (interpret mode)

The resulting dictionary entry is identical in structure to a hand-compiled
colon definition.

### Immediate Words

During compilation, `INTERPRET` compiles every word it finds. But `;` needs
to *execute* even while in compile mode - otherwise you could never end a
definition. Words that execute even in compile mode are called **immediate**
words.

The standard mechanism is a flag bit in the length byte of the dictionary
entry. Using bit 7: a length byte with bit 7 set marks the word as immediate.
`FIND` must be updated to mask off bit 7 when comparing lengths, and
`INTERPRET` must check bit 7 of the found entry's length byte to decide
whether to compile or execute the word.

The word `IMMEDIATE` ( -- ) sets bit 7 of the length byte of the most
recently defined word (i.e., the entry `LATEST` points to). Calling it
immediately after `;`'s own definition marks `;` as immediate.

### Updating INTERPRET

The compile/interpret decision fits naturally into the existing `INTERPRET`
loop. After `FIND` succeeds, instead of always calling `EXECUTE`:

```
FIND DUP
IF                          found:
    immediate? IF           immediate word (or interpret mode):
        NIP NIP EXECUTE
    ELSE                    compile mode, non-immediate:
        NIP NIP ,
    THEN
ELSE                        not found: try NUMBER
    ...
THEN
```

The "immediate?" check combines two conditions: the word is immediate, *or*
we are in interpret mode. Either way, execute it. Only compile it if we are
in compile mode *and* it is not immediate.

When in compile mode and `NUMBER` succeeds, the number should be compiled as
a literal - append `cfa_lit` followed by the number value, rather than
leaving the value on the stack.

---

## The Assignment

Continue working in a new `lab-09/` directory. Copy your `forth.asm`,
`forth.cfg`, and `Makefile` from `lab-08/`.

### Part 1 - HERE, ALLOT, and COMMA

Add a 2-byte `here_ptr` variable in memory (after `word_buf` is a reasonable
place). Implement three words:

- `HERE` ( -- addr ) pushes the value of `here_ptr`
- `ALLOT` ( n -- ) adds n to `here_ptr`
- `,` ( n -- ) stores n as a 16-bit cell at `here_ptr` and adds 2 to
  `here_ptr`

Initialize `here_ptr` at startup to point just past the end of your
pre-defined dictionary (after `word_buf`). You can use a label for this.

Test by calling `HERE` and verifying the address looks reasonable, then
calling `,` with a known value and using `@` to verify the value was written.

### Part 2 - STATE

Add a 2-byte `state_var` variable in memory. Implement `STATE` ( -- addr )
as a word that pushes the *address* of `state_var` (like a FORTH `VARIABLE` -
you use `@` and `!` to read and write it). Initialize `state_var` to zero.

### Part 3 - IMMEDIATE

Implement `IMMEDIATE` ( -- ) as a primitive that sets bit 7 of the length
byte of the entry `LATEST` points to. The length byte is at offset 2 from the
start of the entry.

### Part 4 - The Colon Compiler

Implement `:` and `;`. Both are best written as primitives (assembly code)
for now, since they need to manipulate memory and `STATE` directly.

`:` needs to:
1. Call `WORD` (you can `JSR code_word` directly from assembly, or use a
   helper approach)
2. Write the new dictionary entry using the same layout as your existing
   entries: link field, length+name, then the CFA pointing to `DOCOL`
3. Update `LATEST` and set `STATE`

`;` needs to append `cfa_exit` and clear `STATE`. Mark it immediate by
calling `IMMEDIATE` after its definition.

### Part 5 - Extend INTERPRET

Modify the `INTERPRET` loop to handle compile mode:

- After a successful `FIND`, check both the `STATE` variable and the
  immediate flag to decide whether to execute or compile the word
- After a successful `NUMBER` in compile mode, compile `LIT` followed by
  the number rather than leaving it on the stack

### Part 6 - Test

Boot the interpreter and define a simple word:

```forth
: DOUBLE DUP + ;
4 DOUBLE .
```

Expected output: `8 `. Then try a word with a literal:

```forth
: ADD5 5 + ;
3 ADD5 .
```

Expected output: `8 `.

---

## Questions to Think About

1. `:` reads the new word's name with `WORD`, which returns `( addr len )`.
   How do you write the length byte and name characters into the dictionary
   entry? Do you need a loop?

2. The immediate flag uses bit 7 of the length byte. This limits word names
   to 127 characters. Is that a meaningful constraint? What other bit
   positions or mechanisms could you use instead?

3. When `;` is executing (as an immediate word during compilation), it needs
   to compile `EXIT` and then clear `STATE`. What is on the stack at that
   point, and what does `INTERPRET` do after `;` returns?

4. In compile mode, `NUMBER` should compile a `LIT` followed by the value.
   What would happen if you forgot to do this and just left the number on the
   stack instead?

5. Could `:` itself be written as a FORTH colon definition rather than an
   assembly primitive? What words would it need? What would have to exist
   first?

---

## Stretch Goals

- **`[` and `]`**: Implement `[` (immediate) and `]` as words that switch
  directly to interpret and compile mode respectively. These allow you to
  evaluate expressions at compile time inside a definition, e.g.
  `: FOO [ 2 3 + ] LITERAL + ;`
- **`LITERAL`**: Implement `LITERAL` ( n -- ) as an immediate word that
  compiles `LIT` followed by n. Used with `[...]` to embed computed constants
  into definitions.
- **Recursive definitions**: After `:` creates the dictionary entry and
  updates `LATEST`, the new word is already findable. Can you call a word
  recursively? What is the risk if the definition is incomplete?
- **`WORDS`**: Implement `WORDS` ( -- ) which walks the dictionary from
  `LATEST` and prints every word name. Useful for exploring what's defined.

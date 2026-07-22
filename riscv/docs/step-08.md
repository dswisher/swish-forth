# Step 8: Dictionary Structure, : and ;

## Goal

Define the dictionary header format and implement `:` and `;`. After this
step, new Forth words can be defined using Forth syntax rather than
hand-threaded assembly data.

## Background

### Dictionary Header Format

Each entry in the dictionary has this layout:

```
Offset  Size  Field
------  ----  -----
0       4     Link — pointer to the previous entry's header (0 for first)
4       1     Flags + length — upper bits are flags, lower 5 bits are length
5       n     Name — ASCII characters, not null-terminated
5+n     ?     Padding — to align the CFA to a 4-byte boundary
?       4     CFA — code field address (pointer to code routine)
?+4     ...   Parameter field — body of the word
```

A `LATEST` variable holds the address of the most recently defined word.
`FIND` searches the chain by following link fields.

### STATE

A variable `STATE` controls whether the system is **interpreting** (0) or
**compiling** (non-zero). `:` sets it to compile; `;` sets it back to
interpret.

### : (colon)

`:` is an **immediate** word (executes even during compilation):

1. Read the next word from input (the new word's name)
2. Create a dictionary header with that name, linked to `LATEST`
3. Write `DOCOL` as the code field
4. Update `LATEST` to point to the new header
5. Set `STATE` to compile

### ; (semicolon)

`;` is also **immediate**:

1. Compile `EXIT` into the parameter field
2. Set `STATE` back to interpret

### COMMA (`,`)

The `,` word appends a cell to the dictionary at `HERE` and advances
`HERE` by 4. It is the primitive that both `:` and `;` use internally,
and is also directly useful in Forth-level metacompilation later.

Stack effect: `( n -- )`

## Forth-2012 Reference

- [`:`](https://forth-standard.org/standard/core/Colon)
- [`;`](https://forth-standard.org/standard/core/Semi)
- [`,`](https://forth-standard.org/standard/core/Comma)
- [`HERE`](https://forth-standard.org/standard/core/HERE)
- [`LATEST`](https://forth-standard.org/standard/core/LATEST) (implementation-defined)
- [`STATE`](https://forth-standard.org/standard/core/STATE)

## Files

- `forth.s` — add `,`, `HERE`, `LATEST`, `STATE`, `:`, `;` (update)

## Verification

Hand-code a simple test that:
1. Calls `:` with a name
2. Compiles a few words using the inner compile loop
3. Calls `;`
4. Executes the new word

Inspect the dictionary in memory with GDB to confirm the header structure
is correct.

## Next Step

[Step 9: Outer Interpreter](step-09.md)

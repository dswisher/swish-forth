# Step 9: Dictionary Structure, `CREATE`, `:`, and `;`

## Goal

Define the dictionary header format and implement the words that build new
dictionary entries. After this step, new Forth words can be defined using
Forth syntax rather than hand-threaded assembly data.

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

### `HERE`, `LATEST`, `STATE`

| Variable | Description |
|----------|-------------|
| `HERE`   | Address of the next free byte in data space |
| `LATEST` | Address of the most recently defined dictionary entry |
| `STATE`  | 0 = interpreting, non-zero = compiling |

### `,` (COMMA)

`,` appends a cell to the dictionary at `HERE` and advances `HERE` by 4.
It is the primitive that both `CREATE` and `;` use internally to write into
the dictionary, and is also useful for Forth-level metacompilation later.

Stack effect: `( n -- )`

Forth-2012 reference: [`,`](https://forth-standard.org/standard/core/Comma)

### `CREATE`

`CREATE` is the core word that builds a dictionary header:

1. Call `PARSE-NAME` to parse the next space-delimited name from the input stream
2. Write the link field (pointing to the current `LATEST`)
3. Write the flags+length byte and the name characters
4. Pad to a 4-byte boundary
5. Update `LATEST` to point to the new header
6. Leave `HERE` pointing at the CFA slot (the caller writes the CFA next)

`CREATE` does **not** write a CFA or allocate a data field — that is left
to the caller. `CREATE` is also the foundation for `VARIABLE`, `CONSTANT`,
and `DOES>`.

Stack effect: `( "<spaces>name" -- )`

Forth-2012 reference: [`CREATE`](https://forth-standard.org/standard/core/CREATE)

### `:` (colon)

`:` defines a new colon definition:

1. Call `CREATE` to build the header
2. Write `DOCOL` as the CFA (using `,`)
3. Set `STATE` to compile

`:` is an **immediate** word (executes even during compilation).

Stack effect: `( "<spaces>name" -- )`

Forth-2012 reference: [`:`](https://forth-standard.org/standard/core/Colon)

### `;` (semicolon)

`;` ends a colon definition:

1. Compile `EXIT` into the parameter field (using `,`)
2. Set `STATE` back to interpret (0)

`;` is also **immediate**.

Stack effect: `( -- )`

Forth-2012 reference: [`;`](https://forth-standard.org/standard/core/Semi)

## Implementation notes

`CREATE` depends on `PARSE-NAME` (step 8) being available. The layering is:

```
PARSE-NAME  -- parses a token from >IN, returns ( c-addr u ) into the input buffer
CREATE      -- calls PARSE-NAME, builds the dictionary header
:           -- calls CREATE, writes DOCOL as CFA, sets STATE=compile
;           -- compiles EXIT, resets STATE (immediate)
```

The `IMMEDIATE` flag lives in the flags byte of the header. `:` and `;`
must set this flag on their own entries at definition time (since they must
run during compilation, not be compiled).

## Files

- `forth.s` — add `,`, `HERE`, `LATEST`, `STATE`, `CREATE`, `:`, `;` (update)

## Verification

Hand-code a test that:

1. Pre-loads the input buffer with `": DOUBLE DUP + ;"`
2. Calls `:` (which calls `CREATE` internally)
3. Observes the dictionary header in GDB — check link, flags+length, name,
   padding, and that `DOCOL` is the CFA
4. Simulates compiling `DUP`, `+`, and `EXIT` via `,`
5. Calls `;`
6. Executes the new word `DOUBLE` with a known value on the stack

## Next Step

[Step 10: Outer Interpreter](step-10.md)

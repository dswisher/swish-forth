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

### Supporting primitives

`CREATE` can be implemented as a colon definition, but it requires several
primitives that are not yet present. These must be added to `forth.s` first:

| Word    | Stack effect          | Description |
|---------|-----------------------|-------------|
| `HERE`  | `( -- a-addr )`       | Push address of the `HERE` variable |
| `LATEST`| `( -- a-addr )`       | Push address of the `LATEST` variable |
| `@`     | `( a-addr -- x )`     | Fetch cell from address |
| `!`     | `( x a-addr -- )`     | Store cell to address |
| `C@`    | `( c-addr -- char )`  | Fetch byte from address |
| `C!`    | `( char c-addr -- )`  | Store byte to address |
| `,`     | `( x -- )`            | Append cell at `HERE`, advance `HERE` by 4 |
| `C,`    | `( char -- )`         | Append byte at `HERE`, advance `HERE` by 1 |
| `+`     | `( n1 n2 -- n )`      | Add |
| `AND`   | `( n1 n2 -- n )`      | Bitwise AND |

With these in place, alignment padding can be computed in Forth directly —
no separate `ALLOT` primitive is needed at this stage:

```forth
HERE 3 + -4 AND HERE !
```

This rounds `HERE` up to the next 4-byte boundary.

### `,` (COMMA)

`,` appends a cell to the dictionary at `HERE` and advances `HERE` by 4.
It is used by `CREATE` and `;` to write into the dictionary, and is also
useful for Forth-level metacompilation later.

Stack effect: `( n -- )`

Forth-2012 reference: [`,`](https://forth-standard.org/standard/core/Comma)

### `CREATE`

`CREATE` is the core word that builds a dictionary header. It should be
implemented as a **colon definition** (once the primitives above are in
place) rather than as a raw assembly primitive:

1. Call `PARSE-NAME` to parse the next space-delimited name from the input stream
2. Write the link field (pointing to the current `LATEST`) using `LATEST @ ,`
3. Write the flags+length byte and the name characters using `C,` in a loop
4. Pad `HERE` to a 4-byte boundary: `HERE 3 + -4 AND HERE !`
5. Update `LATEST` to point to the new header using `LATEST !`
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

`CREATE` depends on `PARSE-NAME` (step 8) and the supporting primitives listed
above. The layering is:

```
PARSE-NAME  -- parses a token from >IN, returns ( c-addr u ) into the input buffer
@, !, C@, C!, +, AND, ,, C,  -- primitives used by CREATE
CREATE      -- colon definition: calls PARSE-NAME, builds the dictionary header
:           -- colon definition: calls CREATE, writes DOCOL as CFA, sets STATE=compile
;           -- colon definition: compiles EXIT, resets STATE (immediate)
```

The `IMMEDIATE` flag lives in the flags byte of the header. `:` and `;`
must set this flag on their own entries at definition time (since they must
run during compilation, not be compiled).

## Files

- `forth.s` — add `HERE`, `LATEST`, `STATE`, `@`, `!`, `C@`, `C!`, `,`, `C,`, `+`, `AND`
  as primitives; then implement `CREATE`, `:`, `;` as colon definitions (update)

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

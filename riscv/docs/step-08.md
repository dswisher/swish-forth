# Step 8: Input Buffer, `>IN`, and `WORD`

## Goal

Introduce an input buffer and the `>IN` pointer, then implement `WORD` —
the primitive that parses one space-delimited token from the input stream.
After this step, the system can extract a name from input; the next step
uses that to build dictionary entries.

## Background

### Input buffer

The input buffer is a fixed-size region in memory that holds the current
line of input. Two variables describe it:

| Variable | Description |
|----------|-------------|
| `SOURCE`  | Address and length of the current input buffer (`( -- addr len )`) |
| `>IN`     | Offset (in characters) into the current input buffer; the parse position |

For now the buffer is filled one character at a time from `KEY`, building
up a line until a newline is received. Later (step 11) `REFILL` will be
replaced by `BLOCK`-based source, but the `>IN` / `SOURCE` interface stays
the same.

### `>IN`

`>IN` is a standard variable (`( -- addr )`) whose value is the current
parse position — the byte offset into the buffer returned by `SOURCE`.
`WORD` advances `>IN` as it consumes characters.

Stack effect: `( -- addr )`

Forth-2012 reference: [`>IN`](https://forth-standard.org/standard/core/toIN)

### `WORD`

`WORD` parses the next whitespace-delimited token from the input stream:

1. Skip leading space delimiters starting at `>IN`
2. Collect non-space characters into a scratch buffer
3. Advance `>IN` past the token (and the trailing delimiter, if present)
4. Store the result as a counted string: one length byte followed by the
   characters, with a trailing space appended (ANS requirement)
5. Push the address of the counted string

Stack effect: `( char -- addr )`

The `char` argument is the delimiter character; callers pass `BL` (ASCII
32) for normal whitespace-delimited parsing.

Forth-2012 reference: [`WORD`](https://forth-standard.org/standard/core/WORD)

### `BL`

`BL` is a constant that pushes the ASCII code for space (32). It is the
conventional argument to `WORD` for space-delimited parsing.

Stack effect: `( -- char )`

Forth-2012 reference: [`BL`](https://forth-standard.org/standard/core/BL)

### Word buffer (`WORD_BUFFER`)

`WORD` writes into a dedicated scratch buffer — not into the dictionary.
The buffer needs to be large enough for the longest word name; 32 bytes is
sufficient for a minimal kernel.

## Implementation notes

`WORD` is implemented as an assembly primitive. It uses `>IN` and the
buffer address/length from `SOURCE` rather than calling `KEY` directly.
This keeps it decoupled from the I/O layer and makes it reusable when the
source later switches to block memory.

The `REFILL` word (not implemented here) is responsible for reading a new
line into the input buffer and resetting `>IN` to zero. For this step,
testing can be done by pre-populating the input buffer in the hand-threaded
test harness.

## Files

- `forth.s` — add `BL`, `>IN`, `WORD` (update)

## Verification

Pre-load the input buffer with a known string (e.g., `"  HELLO  WORLD"`)
in the hand-threaded test, then call `BL WORD`. Inspect the word buffer in
GDB and confirm:

- The length byte is correct (5 for `HELLO`)
- The characters match
- `>IN` has advanced to just past `HELLO`
- A second `BL WORD` call picks up `WORLD`

## Next Step

[Step 9: Dictionary Structure, `CREATE`, `:`, and `;`](step-09.md)

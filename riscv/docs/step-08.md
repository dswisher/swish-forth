# Step 8: Input Buffer, `>IN`, and `PARSE-NAME`

## Goal

Introduce an input buffer and the `>IN` pointer, then implement
`PARSE-NAME` — the primitive that parses one space-delimited token from
the input stream. After this step, the system can extract a name from
input; the next step uses that to build dictionary entries.

## Background

### Input buffer

The input buffer is a fixed-size region in memory that holds the current
line of input. Two words describe it:

| Word      | Stack          | Description |
|-----------|----------------|-------------|
| `SOURCE`  | `( -- addr u )` | Address and length of the current input buffer |
| `>IN`     | `( -- addr )`   | Address of a cell holding the parse offset in characters from the start of the input buffer |

For now the buffer is filled one character at a time from `KEY`, building
up a line until a newline is received. Later (step 11) `REFILL` will be
replaced by `BLOCK`-based source, but the `SOURCE` / `>IN` interface stays
the same throughout.

Forth-2012 reference: [`SOURCE`](https://forth-standard.org/standard/core/SOURCE),
[`>IN`](https://forth-standard.org/standard/core/toIN)

### `PARSE-NAME`

`PARSE-NAME` is the preferred Forth-2012 word for parsing a
space-delimited name. It operates directly on the input buffer described
by `SOURCE` and `>IN`:

1. Skip leading space delimiters starting at the current `>IN` offset
2. Mark the start of the token
3. Advance past non-space characters to find the end of the token
4. Update `>IN` to point just past the token (or to the end of the buffer)
5. Return the address and length of the token **within the input buffer** —
   no copy is made

Stack effect: `( "<spaces>name<space>" -- c-addr u )`

If the parse area is empty or contains only whitespace, `u` is zero.

Forth-2012 reference:
[`PARSE-NAME`](https://forth-standard.org/standard/core/PARSE-NAME)
(Core Ext, 6.2.2020)

The key advantage over the older `WORD` is that `PARSE-NAME` returns a
`( c-addr u )` pair pointing directly into the input buffer. No scratch
buffer is needed, no copy is performed, and the result is a standard
address-length string compatible with all other string words.

### `WORD` (compatibility wrapper)

`WORD` (Core, 6.1.2450) is the older parsing word. It takes a delimiter
character, copies the parsed token into a transient scratch buffer as a
counted string (one length byte followed by characters), and returns the
address of that buffer. It must be present in a Forth-2012 system.

Because it copies into a scratch buffer, its result is transient and can
be clobbered — the standard explicitly warns about this. It should not be
used in new code; `PARSE-NAME` or `PARSE` are preferred.

For this kernel, `WORD` is implemented in Forth on top of `PARSE-NAME`
once a scratch buffer and `COUNT` exist. It does not need to be an
assembly primitive.

Stack effect: `( char -- c-addr )`

Forth-2012 reference: [`WORD`](https://forth-standard.org/standard/core/WORD)

## Implementation notes

`PARSE-NAME` is implemented as an assembly primitive. The algorithm is
straightforward: load `SOURCE` to get the buffer base and length, load
`>IN` to get the current offset, scan forward skipping spaces, record the
start, scan forward collecting non-spaces, compute the length, update
`>IN`, and push `( c-addr u )`.

`REFILL` (not implemented here) is responsible for reading a new line into
the input buffer and resetting `>IN` to zero. For this step, testing can
be done by pre-populating the input buffer in the hand-threaded test
harness.

## Files

- `forth.s` — add `SOURCE`, `>IN`, `PARSE-NAME` (update)

## Verification

Pre-load the input buffer with a known string (e.g., `"  HELLO  WORLD"`)
in the hand-threaded test, then call `PARSE-NAME`. Inspect registers and
memory in GDB and confirm:

- `c-addr` points into the input buffer at `H`
- `u` is 5
- `>IN` has advanced to just past `HELLO`
- A second `PARSE-NAME` call returns `c-addr` pointing at `W` with `u` = 5

## Next Step

[Step 9: Dictionary Structure, `CREATE`, `:`, and `;`](step-09.md)

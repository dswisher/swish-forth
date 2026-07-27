# Makefile for swish-forth: RISC-V 32-bit bare-metal
#
# Builds and runs natively on macOS (no Docker required).
# Requires: riscv64-elf-binutils, riscv64-elf-gdb (brew install),
#           qemu (brew install, provides qemu-system-riscv32)
#
# Usage:
#   make                - assemble and link
#   make run            - run under QEMU (I/O on this terminal)
#   make debug          - run GDB with QEMU as a subprocess (single window)
#   make qemu-wait      - run under QEMU, halted, waiting for GDB (window 1)
#   make gdb-attach     - connect GDB to a waiting QEMU instance  (window 2)
#   make disasm         - disassemble the binary
#   make clean          - remove build artifacts
#
# Platform selection:
#   make PLATFORM=qemu-virt   (default)
#
# Two-window debug workflow (alternative to 'make debug'):
#   Terminal 1: make qemu-wait      <- I/O and program output appear here
#   Terminal 2: make gdb-attach     <- set breakpoints, then 'continue'

PLATFORM ?= qemu-virt

AS       := riscv64-elf-as
LD       := riscv64-elf-ld
GDB      := riscv64-elf-gdb
OBJDUMP  := riscv64-elf-objdump
QEMU     := qemu-system-riscv32

ASFLAGS  := -march=rv32i -mabi=ilp32 -g
LDFLAGS  := -m elf32lriscv -T forth.ld --no-relax --no-warn-rwx-segments

TARGET   := forth.elf
SRCS     := forth.s platform/$(PLATFORM).s blocks.s
OBJS     := $(SRCS:.s=.o)

QEMU_FLAGS  := -machine virt -nographic -bios none -kernel $(TARGET) -echr 0x1c

GDB_PORT    := 1234
GDB_REMOTE  := -ex "target remote :$(GDB_PORT)"
GDB_FLAGS   := -ex "set architecture riscv:rv32" \
               -ex "break halt_code" \
               -ex "layout split"

# ── Phony targets ──────────────────────────────────────────────────────────────

.PHONY: all run qemu-wait gdb-attach debug disasm clean blocks-s

all: $(TARGET)

$(TARGET): $(OBJS) forth.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

forth.o: forth.s forth.inc
	$(AS) $(ASFLAGS) -o $@ $<

blocks.s: tools/mkblocks.py
	python3 tools/mkblocks.py -o $@ blocks

blocks.o: blocks.s
	$(AS) $(ASFLAGS) -o $@ $<

platform/$(PLATFORM).o: platform/$(PLATFORM).s forth.inc
	$(AS) $(ASFLAGS) -o $@ $<

# ── Regenerate blocks.s explicitly (also done automatically during build)
blocks-s:
	python3 tools/mkblocks.py -o blocks.s blocks

# Run the binary under QEMU (Ctrl-A X to exit QEMU)
run: $(TARGET)
	$(QEMU) $(QEMU_FLAGS)

# Run under QEMU with GDB stub; QEMU halts before first instruction (window 1)
qemu-wait: $(TARGET)
	$(QEMU) $(QEMU_FLAGS) -s -S

# Connect GDB to a waiting QEMU instance (window 2)
gdb-attach: $(TARGET)
	$(GDB) -q $(GDB_REMOTE) $(GDB_FLAGS) $(TARGET)

# Run GDB, launching QEMU as a background subprocess (single-window debug workflow)
# QEMU I/O goes to /dev/null since -nographic conflicts with the GDB pipe approach.
debug: $(TARGET)
	$(QEMU) $(QEMU_FLAGS) -s -S &
	sleep 0.5
	$(GDB) -q $(GDB_REMOTE) $(GDB_FLAGS) $(TARGET)
	pkill -f "$(QEMU).*$(TARGET)" 2>/dev/null || true

# Disassemble the binary (useful for verifying macro expansion)
disasm: $(TARGET)
	$(OBJDUMP) -d -M no-aliases $(TARGET)

# Make tags
tags:
	/opt/homebrew/bin/ctags -R .

# Remove build artifacts
clean:
	rm -f $(TARGET) $(OBJS) blocks.s


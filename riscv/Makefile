# Makefile for swish-forth: RISC-V 32-bit bare-metal
#
# Builds and runs natively on macOS (no Docker required).
# Requires: riscv64-elf-binutils, riscv64-elf-gdb (brew install),
#           qemu (brew install, provides qemu-system-riscv32)
#
# Usage:
#   make                - assemble and link
#   make run            - run under QEMU (I/O on this terminal)
#   make qemu-wait      - run under QEMU, halted, waiting for GDB (window 1)
#   make gdb-attach     - connect GDB to a waiting QEMU instance  (window 2)
#   make disasm         - disassemble the binary
#   make clean          - remove build artifacts
#
# Platform selection:
#   make PLATFORM=qemu-virt   (default)
#
# Two-window debug workflow:
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
SRCS     := forth.s platform/$(PLATFORM).s
OBJS     := $(SRCS:.s=.o)

GDB_PORT    := 1234
QEMU_FLAGS  := -machine virt -nographic -bios none -kernel $(TARGET)

# ── Phony targets ──────────────────────────────────────────────────────────────

.PHONY: all run qemu-wait gdb-attach disasm clean

all: $(TARGET)

$(TARGET): $(OBJS) forth.ld
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

forth.o: forth.s forth.inc
	$(AS) $(ASFLAGS) -o $@ $<

platform/$(PLATFORM).o: platform/$(PLATFORM).s forth.inc
	$(AS) $(ASFLAGS) -o $@ $<

# Run the binary under QEMU (Ctrl-A X to exit QEMU)
run: $(TARGET)
	$(QEMU) $(QEMU_FLAGS)

# Run under QEMU with GDB stub; QEMU halts before first instruction (window 1)
qemu-wait: $(TARGET)
	$(QEMU) $(QEMU_FLAGS) -s -S

# Connect GDB to a waiting QEMU instance (window 2)
gdb-attach: $(TARGET)
	$(GDB) -q \
	    -ex "set architecture riscv:rv32" \
	    -ex "target remote :$(GDB_PORT)" \
	    -ex "break _start" \
	    -ex "break NOP_code" \
	    -ex "break EMIT_code" \
	    -ex "break EXIT_code" \
	    -ex "layout split" \
	    $(TARGET)

# Disassemble the binary (useful for verifying macro expansion)
disasm: $(TARGET)
	$(OBJDUMP) -d -M no-aliases $(TARGET)

# Remove build artifacts
clean:
	rm -f $(TARGET) $(OBJS)


# Makefile for RISC-V 32-bit Forth kernel development
#
# All assembly and execution happens inside a Docker container
# to ensure a consistent environment across Mac, Windows, and Linux.
#
# Usage:
#   make image       - build the Docker image (do this first)
#   make             - assemble all .s files
#   make run         - run the binary under qemu
#   make debug       - start binary under qemu with GDB stub, then launch gdb
#   make clean       - remove build artifacts
#   make shell       - open a shell in the container (for exploration)

IMAGE   := swish-forth-riscv
WORKDIR := /work

AS      := riscv64-linux-gnu-as
LD      := riscv64-linux-gnu-ld
GDB     := gdb-multiarch
QEMU    := qemu-riscv32

ASFLAGS := -march=rv32i -mabi=ilp32 -g
LDFLAGS := -m elf32lriscv

TARGET  := forth
SRCS    := forth.s
OBJS    := $(SRCS:.s=.o)

GDB_PORT := 1234

# Run a command inside the Docker container with the project mounted
DOCKER_RUN := docker run --rm -i \
    -v "$(shell pwd)":$(WORKDIR) \
    $(IMAGE)

# ── Phony targets ──────────────────────────────────────────────────────────────

.PHONY: all image run debug shell clean disasm

all: $(TARGET)

# Build the Docker image
image:
	docker build -t $(IMAGE) .

# Assemble and link inside the container
$(TARGET): $(OBJS)
	$(DOCKER_RUN) $(LD) $(LDFLAGS) -o $(TARGET) $(OBJS)

%.o: %.s
	$(DOCKER_RUN) $(AS) $(ASFLAGS) -o $@ $<

# Run the binary under QEMU
run: $(TARGET)
	$(DOCKER_RUN) $(QEMU) ./$(TARGET)

# Debug: launch QEMU with GDB stub and connect gdb-multiarch.
# Uses a pseudo-TTY (-t) so GDB's TUI works correctly.
debug: $(TARGET)
	docker run --rm -it \
	    -v "$(shell pwd)":$(WORKDIR) \
	    $(IMAGE) \
	    sh -c '$(QEMU) -g $(GDB_PORT) ./$(TARGET) & \
	           sleep 0.2 && \
	           $(GDB) -q \
	               -ex "set architecture riscv:rv32" \
	               -ex "target remote :$(GDB_PORT)" \
	               -ex "layout asm" \
	               -ex "layout regs" \
	               ./$(TARGET)'

# Open an interactive shell in the container
shell:
	docker run --rm -it \
	    -v "$(shell pwd)":$(WORKDIR) \
	    $(IMAGE) \
	    bash

# Remove build artifacts (not the Docker image)
clean:
	$(DOCKER_RUN) sh -c 'rm -f $(TARGET) $(OBJS)'

# Disassemble the binary (useful for verifying macro expansion)
disasm: $(TARGET)
	$(DOCKER_RUN) riscv64-linux-gnu-objdump -d -M no-aliases $(TARGET)

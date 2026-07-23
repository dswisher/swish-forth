FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    binutils-riscv64-linux-gnu \
    gcc-riscv64-linux-gnu \
    libc6-dev-riscv64-cross \
    qemu-user \
    gdb-multiarch \
    make \
    file \
    && rm -rf /var/lib/apt/lists/*

COPY .gdbinit /root/.gdbinit
COPY .inputrc /root/.inputrc

WORKDIR /work

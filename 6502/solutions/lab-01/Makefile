
.PHONY: all run clean

all: hello.prg

run: hello.prg
	x16emu -rom ~/.local/share/x16/rom.bin -prg hello.prg -scale 2 -run

clean:
	rm -f hello.prg hello.o

hello.o: hello.asm
	ca65 hello.asm

hello.prg: hello.o hello.cfg
	ld65 -C hello.cfg -o hello.prg hello.o


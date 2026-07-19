RUN = x16emu -rom ~/.local/share/x16/rom.bin -prg forth.prg -scale 2 -run

.PHONY: all run clean

all: forth.prg

run: forth.prg
	$(RUN)

debug: forth.prg
	$(RUN) -debug 0x080d

clean:
	rm -f forth.prg forth.o forth.lst

forth.o: forth.asm
	ca65 forth.asm -l forth.lst

forth.prg: forth.o forth.cfg
	ld65 -C forth.cfg -o forth.prg forth.o


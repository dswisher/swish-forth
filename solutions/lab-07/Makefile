RUN = x16emu -rom ~/.local/share/x16/rom.bin -prg forth.prg -scale 2 -run

BREAK_SYM = code_0branch
BREAK_ADDR = $(shell grep 'name="$(BREAK_SYM)"' forth.dbg | sed 's/.*val=\([^,]*\).*/\1/')

.PHONY: all run clean

all: forth.prg

run: forth.prg
	$(RUN)

debug: forth.prg
	$(RUN) -debug $(BREAK_ADDR)

clean:
	rm -f forth.prg forth.o forth.lst forth.dbg

forth.o: forth.asm
	ca65 -g forth.asm -l forth.lst

forth.prg: forth.o forth.cfg
	ld65 -C forth.cfg -o forth.prg --dbgfile forth.dbg forth.o


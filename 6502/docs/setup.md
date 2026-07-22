# Setup

Instructions for installing the required toolchain on Mac, Windows, and Linux.

## Tools Required

- **cc65** - 6502 assembler and linker (`ca65` + `ld65`)
- **Commander X16 Emulator** - target platform emulator

---

## Mac

### cc65

The easiest path is Homebrew:

```zsh
brew install cc65
```

Verify:

```zsh
ca65 --version
ld65 --version
```

### Commander X16 Emulator

Download the latest release from the
[x16-emulator releases page](https://github.com/X16Community/x16-emulator/releases).
Look for the macOS binary (e.g., `x16emu-mac-r48.zip` or similar).

Unzip and install the binary and ROM into your home directory:

```zsh
unzip x16emu-mac-*.zip -d x16emu
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/x16
cp x16emu/x16emu ~/.local/bin/
cp x16emu/rom.bin ~/.local/share/x16/
```

Make sure `~/.local/bin` is on your PATH. Add this to `~/.zshrc` if it isn't
already:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Then reload your shell:

```zsh
source ~/.zshrc
```

Verify:

```zsh
x16emu -rom ~/.local/share/x16/rom.bin
```

The emulator window should open to the X16 BASIC prompt.

> **Note**: macOS may quarantine the downloaded binary. If you see a security
> warning, run:
> ```zsh
> xattr -d com.apple.quarantine ~/.local/bin/x16emu
> ```

---

## Linux

### cc65

Most distributions package cc65:

```bash
# Debian / Ubuntu
sudo apt install cc65

# Fedora
sudo dnf install cc65

# Arch
sudo pacman -S cc65
```

If your distro's package is outdated, build from source:

```bash
git clone https://github.com/cc65/cc65.git
cd cc65
make
sudo make install PREFIX=/usr/local
```

### Commander X16 Emulator

Download the Linux binary from the
[x16-emulator releases page](https://github.com/X16Community/x16-emulator/releases).

```bash
unzip x16emu-linux-r*.zip -d x16emu
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/x16
cp x16emu/x16emu ~/.local/bin/
cp x16emu/rom.bin ~/.local/share/x16/
```

`~/.local/bin` is typically on the PATH by default on most Linux distributions.
If it isn't, add this to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Verify:

```bash
x16emu -rom ~/.local/share/x16/rom.bin
```

---

## Windows

### cc65

Download the Windows binaries from the
[cc65 snapshot page](https://sourceforge.net/projects/cc65/files/cc65-snapshot-win32.zip).

Unzip and add the `bin\` directory to your `PATH` via System Properties ->
Environment Variables.

Alternatively, if you use [Scoop](https://scoop.sh/):

```powershell
scoop install cc65
```

Verify in PowerShell or Command Prompt:

```powershell
ca65 --version
ld65 --version
```

### Commander X16 Emulator

Download the Windows binary from the
[x16-emulator releases page](https://github.com/X16Community/x16-emulator/releases).

Unzip to a folder (e.g., `C:\x16emu\`), then add that folder to your `PATH`.
The `rom.bin` file from the same zip must be in the same directory as
`x16emu.exe`, or passed explicitly with `-rom`.

Verify in PowerShell:

```powershell
x16emu.exe
```

---

## Host Filesystem (SD Card Emulation)

The X16 emulator can map a directory on your host machine to a virtual SD
card. This is the mechanism used to load `.forth` source files into the
emulator without burning them to a disk image.

Start the emulator with the `-sdcard` flag pointing at a directory:

```zsh
x16emu -rom ~/.local/share/x16/rom.bin -sdcard /path/to/swish-forth/forth
```

Any files in that directory are visible to the X16 as files on drive 8.
When your FORTH `LOAD` word opens a file by name, it will find files placed
there by your editor on the host.

A convenience shell alias (add to `~/.zshrc` on Mac/Linux):

```zsh
alias x16='x16emu -rom ~/.local/share/x16/rom.bin -sdcard /path/to/swish-forth/forth'
```

---

## Neovim

No special configuration is required. For syntax highlighting of `.asm` /
`.s` files, the
[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) plugin
with the `asm` grammar works well.

For `.forth` files, a simple filetype detection line in your Neovim config
is sufficient for now:

```lua
vim.filetype.add({ extension = { forth = "forth" } })
```

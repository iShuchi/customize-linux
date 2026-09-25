# Turning Linux Into Home

A virtual home which always makes me comfortable to code. There are different
shell scripts around here and each is responsible for installing packages and
completing a setup.

**Setup:** To setup given any of the utility, simply run `./setup-<name>.sh` and
if the utility is already installed, then one can use `./setup-<name>.sh -i` to
copy paste the configuration inside `~/.config/<utility>`.

## NEOVIM

Being a strong command line-based editor, NVIM creates comfortable environment
for programming without touching your mouse.

### 1. Keybindings

**NOTE:** `<leader>` is `Space`.

I've choosen to not go with NvChad's keybindings and rather use the ones which
I've made being inspired from VS Code keybindings. Use `<leader>+ch` to see
complete set of keybindings.

### 2. Display

Here is how it looks so far :-)

![NVIM Interface](images/demo-nvim.gif)

## TERMINATOR

A terminal with the Bright Lights theme is installed under this setup. The
config and the TerminatorThemes plugin live in `terminator/`.

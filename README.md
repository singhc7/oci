# OCI Dotfiles

Configuration for a headless **Ubuntu** instance running on Oracle Cloud
Infrastructure (OCI), accessed exclusively over SSH. Trimmed down from my
desktop dotfiles — no GUI, no Wayland, no audio/video tooling.

## What's in here

| Stow package | Purpose                                                |
| ------------ | ------------------------------------------------------ |
| `zsh`        | Login shell (Antidote, Powerlevel10k, vi mode)         |
| `bash`       | Non-interactive / fallback shell                       |
| `tmux`       | Persistent SSH sessions, OSC 52 clipboard pass-through |
| `neovim`     | Editor (Lazy + LSP + Treesitter)                       |
| `git`        | Aliases, SSH commit signing, sane defaults             |
| `fzf`        | Fuzzy finder integrations for shell + bat preview      |
| `eza`        | `ls` replacement with theme                            |
| `btop`       | TUI system monitor                                     |
| `nnn`        | TUI file manager + curated plugin set                  |
| `tealdeer`   | tldr-pages client                                      |
| `aria2`      | Headless download daemon                               |
| `yt-dlp`     | Media download CLI                                     |
| `scripts`    | Personal `~/.local/bin/scripts` shims                  |

## Prerequisites

- Ubuntu 24.04 LTS (the bootstrap script also runs on 22.04, but a few
  CLI tools — `btop`, `eza`, `tealdeer` — aren't in 22.04's default
  archive and will be skipped).
- An SSH user with `sudo`. On default OCI images that's `ubuntu`.

## Bootstrap

```bash
sudo apt-get update && sudo apt-get install -y git stow
git clone https://github.com/singhc7/oci ~/dotfiles
cd ~/dotfiles
./forge
```

`forge` will:

1. `apt full-upgrade` the system.
2. Install the headless package set with `--no-install-recommends`.
3. Symlink `~/.local/bin/{bat,fd}` to Ubuntu's `batcat` / `fdfind` so
   configs that reference the upstream binary names keep working.
4. Run `stow -R` for every package above.
5. Hand off to `./forge-nvim` to install the Neovim toolchain (PPA
   neovim, node/npm, default-jre, tree-sitter CLI, etc.) and run a
   headless Lazy + Mason sync.
6. Install [Antidote](https://github.com/mattmc3/antidote) for zsh.
7. `chsh` you to `zsh` if it isn't already your login shell.

### Refreshing Neovim deps

If Mason can't fetch a tool because a runtime is missing, re-run the
nvim bootstrap on its own — it's idempotent:

```bash
./forge-nvim
```

It pre-stages everything Mason and `nvim-treesitter` need (node, java,
gcc, tree-sitter CLI, ripgrep, fd) and triggers a headless `:Lazy sync`
followed by `:MasonToolsInstallSync`. Verify with `:checkhealth` after.

Log out and back in once it finishes so the new symlinks and shell take
effect.

## Manual install

If you'd rather skip `forge`, install `stow` and link only the packages
you want:

```bash
cd ~/dotfiles
stow zsh tmux neovim git fzf
```

## License

Dual-licensed under [CC BY-NC-SA 4.0](LICENSE-CC-BY-NC-SA) and
[PolyForm Noncommercial 1.0.0](LICENSE-POLYFORM). Free for personal,
educational, and charitable use; commercial use requires a separate
license — contact me.

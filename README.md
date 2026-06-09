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

## Manual install

```bash
cd ~/dotfiles
stow zsh tmux neovim git fzf
```

## License

Dual-licensed under [CC BY-NC-SA 4.0](LICENSE-CC-BY-NC-SA) and
[PolyForm Noncommercial 1.0.0](LICENSE-POLYFORM). Free for personal,
educational, and charitable use; commercial use requires a separate
license — contact me.

# ==========================================
# Shell Options & Keybindings
# ==========================================

# --- Completion ---
# Antidote handles fpath for plugins; we still need to call compinit ourselves.
# Cache the dump under XDG to keep $HOME clean and speed up subsequent shells.
typeset -g _zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
[[ -d "${_zcompdump:h}" ]] || mkdir -p "${_zcompdump:h}"
autoload -Uz compinit
compinit -d "$_zcompdump"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{246}-- %d --%f'
zstyle ':completion:*' group-name ''

# --- Vi Mode ---
bindkey -v          # Enable vi mode
export KEYTIMEOUT=1 # Reduce escape delay to 10ms

# Enable beginning-of-line aware history search (better than plain up/down).
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^P' up-line-or-beginning-search
bindkey '^N' down-line-or-beginning-search

# Better searching in vi mode
# (fzf usually handles these, but good to have fallbacks)
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# History substring search (filter history by what's already typed)
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# Standard emacs-style bindings in insert mode for convenience
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' backward-kill-line
bindkey '^W' backward-kill-word
bindkey '^H' backward-delete-char

# Use 'jk' to quickly enter normal mode
bindkey -M viins 'jk' vi-cmd-mode

# --- Edit Command Line in Editor ---
# This allows you to press 'v' in Normal mode to open the current buffer in Neovim
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# Ensure the associative array exists before we try to populate it
typeset -gA ZSH_HIGHLIGHT_STYLES

# --- Syntax Highlighting Styles ---
# Bold for commands and programs
ZSH_HIGHLIGHT_STYLES[command]='bold'
ZSH_HIGHLIGHT_STYLES[alias]='bold'
ZSH_HIGHLIGHT_STYLES[builtin]='bold'
ZSH_HIGHLIGHT_STYLES[function]='bold'
ZSH_HIGHLIGHT_STYLES[precommand]='bold'
ZSH_HIGHLIGHT_STYLES['single-hyphen-option']='none'
ZSH_HIGHLIGHT_STYLES['double-hyphen-option']='none'

# Other styling
ZSH_HIGHLIGHT_STYLES[path]='underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='underline'
ZSH_HIGHLIGHT_STYLES[globbing]='none'

# --- Output Reset ---
# Load terminfo module to ensure $terminfo is available
zmodload zsh/terminfo
preexec() {
    # Reset all text attributes (bold, italics, etc.) before command output
    print -rn "$terminfo[sgr0]"
}

# --- History ---
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt appendhistory
setopt sharehistory
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
setopt hist_reduce_blanks
setopt hist_ignore_space

# --- General ---
setopt autocd              # If a command is a directory, cd into it
setopt interactivecomments # Allow comments in interactive shells
setopt notify              # Notify of background job completion immediately
setopt extended_glob       # Powerful globbing (^, ~, # operators)
setopt no_clobber          # Refuse to overwrite files with `>`; use `>!` to force
setopt long_list_jobs      # Show job number, state, and full command
setopt pushd_ignore_dups   # Don't keep duplicate dirs in the dirstack

# .bashrc

# ==========================================
# 1. Environment Variables & PATH
# ==========================================
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export EDITOR='nvim'
export VISUAL='nvim'

# Load Cargo (if installed)
if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
fi

# Load Deno (if installed)
if [ -f "$HOME/.deno/env" ]; then
    . "$HOME/.deno/env"
fi

# ==========================================
# 2. Interactive Shell Settings
# ==========================================
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Prompt (Minimalist)
# λ if last command succeeded, red λ if it failed
# format: [user@host:cwd] λ
_bash_prompt() {
    local EXIT="$?"
    local GREEN="\[\e[1;32m\]"
    local RED="\[\e[1;31m\]"
    local RESET="\[\e[0m\]"

    if [ $EXIT -eq 0 ]; then
        PS1="${GREEN}[\u@\h:\w]${RESET} ${GREEN}λ${RESET} "
    else
        PS1="${GREEN}[\u@\h:\w]${RESET} ${RED}λ${RESET} "
    fi
}
PROMPT_COMMAND=_bash_prompt

# Bash Completion
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# History Settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

# ==========================================
# 3. Aliases
# ==========================================
# Modern replacement for ls (eza)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git --group-directories-first'
    alias la='eza -lha --icons --git --group-directories-first'
    alias lt='eza --tree --icons --group-directories-first'
    alias l.='eza -d .* --icons --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh'
    alias la='ls -lha'
fi

# Linux-specific extras (nnn config, apt aliases)
[[ -f ~/.bashrc.linux ]] && . ~/.bashrc.linux

# ==========================================
# 4. Integrations
# ==========================================
# Load fzf configuration
[[ -f ~/.config/fzf/fzf.bash ]] && . ~/.config/fzf/fzf.bash

# Load zoxide configuration (Must be at the end)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

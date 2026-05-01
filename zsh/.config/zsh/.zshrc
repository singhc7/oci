# 1. Powerlevel10k Instant Prompt (Must be at the very top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${USER}.zsh"
fi

# 2. Load Antidote (Your Plugin Manager)
source ~/.antidote/antidote.zsh

# 3. Load your plugins (Includes Powerlevel10k, Autosuggestions, etc.)
antidote load

# 4. Load Powerlevel10k Visual Settings
[[ ! -f ${ZDOTDIR:-~}/.p10k.zsh ]] || source ${ZDOTDIR:-~}/.p10k.zsh

# ==========================================
# Modular Configurations
# ==========================================
# Use ~/.zsh if it exists (standard Stow behavior)
ZSH_CONFIG_DIR="$ZDOTDIR/.zsh"

# If ~/.zsh doesn't exist, fall back to the relative path of this script
if [[ ! -d "$ZSH_CONFIG_DIR" ]]; then
    ZSH_CONFIG_DIR="${${(%):-%x}:h}/.zsh"
fi

# 1. Exports first (sets up PATH for tools)
[[ -f "$ZSH_CONFIG_DIR/exports.zsh" ]] && source "$ZSH_CONFIG_DIR/exports.zsh"

# 2. Options next (sets up shell options and keybindings like vi-mode)
[[ -f "$ZSH_CONFIG_DIR/options.zsh" ]] && source "$ZSH_CONFIG_DIR/options.zsh"

# 3. Integrations next (initializes tools using PATH)
[[ -f "$ZSH_CONFIG_DIR/integrations.zsh" ]] && source "$ZSH_CONFIG_DIR/integrations.zsh"

# 4. Everything else
for config in functions aliases; do
    if [[ -f "$ZSH_CONFIG_DIR/$config.zsh" ]]; then
        source "$ZSH_CONFIG_DIR/$config.zsh"
    fi
done

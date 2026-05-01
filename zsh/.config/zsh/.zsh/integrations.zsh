# ==========================================
# External Tool Integrations
# ==========================================

# --- fzf ---
[[ -f ~/.config/fzf/fzf.zsh ]] && source ~/.config/fzf/fzf.zsh

# --- zoxide ---
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    export _ZO_MAXAGE=10000
fi

# --- direnv (lazy) ---
# Eager `eval $(direnv hook zsh)` adds startup cost on every shell.
# Defer hook installation until cwd actually has .envrc/.env.
# To restore eager mode: replace this block with `eval "$(direnv hook zsh)"`.
if command -v direnv >/dev/null 2>&1; then
    _direnv_lazy_load() {
        if [[ -f .envrc || -f .env ]]; then
            eval "$(direnv hook zsh)"
            add-zsh-hook -d chpwd _direnv_lazy_load
            unset -f _direnv_lazy_load
            _direnv_hook
        fi
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _direnv_lazy_load
    _direnv_lazy_load  # handle case where shell starts inside an .envrc dir
fi

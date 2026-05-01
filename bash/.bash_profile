# .bash_profile

# If running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# Load user-specific environment variables that are NOT bash-specific
# (e.g., Cargo, Deno) - often handled in .bashrc for simplicity

#!/bin/bash

# Define paths
DOTFILES_DIR="$HOME"
CONFIG_DIR="$HOME/.config"
LOCAL_DIR="$HOME/.local"
LOCAL_BIN="$LOCAL_DIR/bin"
LOCAL_LIB="$LOCAL_DIR/lib"
LOCAL_COMPLETION="$LOCAL_DIR/share/bash-completion/completions"

# Create necessary directories
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOCAL_BIN"
mkdir -p "$LOCAL_LIB"
mkdir -p "$LOCAL_COMPLETION"

# Symlink the config directory
ln -sfn "$DOTFILES_DIR/.config/pwmanager" "$CONFIG_DIR/pwmanager"

# Symlink the executable
ln -sfn "$CONFIG_DIR/pwmanager/bin/password" "$LOCAL_BIN/password"

# Symlink the Python package
ln -sfn "$CONFIG_DIR/pwmanager/lib/pwmanager" "$LOCAL_LIB/pwmanager"

# Symlink the completion file
ln -sfn "$CONFIG_DIR/pwmanager/shell/completion/password" "$LOCAL_COMPLETION/password"

# Make the password script executable
chmod +x "$CONFIG_DIR/pwmanager/bin/password"

# Install dependencies
# pip install --user keyring

# Add .pth file for pyenv environments (optional)
if command -v pyenv >/dev/null 2>&1; then
    for PYTHON in $(pyenv versions --bare 2>/dev/null); do
        PYENV_PREFIX=$(pyenv prefix "$PYTHON" 2>/dev/null)
        if [ -n "$PYENV_PREFIX" ] && [ -d "$PYENV_PREFIX" ]; then
            SITE_PACKAGES=$(find "$PYENV_PREFIX/lib" -type d -name "site-packages" 2>/dev/null | head -n 1)
            if [ -n "$SITE_PACKAGES" ]; then
                echo "$LOCAL_LIB" > "$SITE_PACKAGES/pwmanager.pth"
            fi
        fi
    done
fi


#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only."
    exit 1
fi

echo -e "${GREEN}"
echo "╔═══════════════════════════════════════╗"
echo "║     Dotfiles Setup Script             ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Install Homebrew if needed
print_step "Checking Homebrew installation..."
if ! command_exists brew; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    print_success "Homebrew installed"
else
    print_success "Homebrew already installed"
fi

# Update Homebrew
print_step "Updating Homebrew..."
brew update

# Install everything from the Brewfile (taps, formulae, casks, and uv/npm/cargo tools).
# The Brewfile is the single source of truth for installed packages.
# Refresh the snapshot with:  brew bundle dump --file=~/.config/Brewfile --force
# (then re-add the hand-maintained tools flagged in the Brewfile's "Manually added" block).
print_step "Installing packages from Brewfile..."
BREWFILE="$HOME/.config/Brewfile"
if [[ ! -f "$BREWFILE" ]]; then
    print_error "Brewfile not found at $BREWFILE"
    exit 1
fi
if brew bundle install --file="$BREWFILE"; then
    print_success "Brewfile packages installed"
else
    print_warning "Some Brewfile entries failed to install (continuing setup)"
fi

# Setup Zsh
print_step "Setting up Zsh configuration..."

# Create symlinks
if [[ -L ~/.zshenv ]]; then
    # If it's a symlink, remove and recreate it
    rm ~/.zshenv
    ln -sf ~/.config/zsh/symlink/.zshenv ~/.zshenv
    print_success "Updated .zshenv symlink"
elif [[ ! -f ~/.zshenv ]]; then
    ln -sf ~/.config/zsh/symlink/.zshenv ~/.zshenv
    print_success "Created .zshenv symlink"
else
    print_warning ".zshenv exists but is not a symlink. Backing up and creating symlink..."
    mv ~/.zshenv ~/.zshenv.backup.$(date +%Y%m%d_%H%M%S)
    ln -sf ~/.config/zsh/symlink/.zshenv ~/.zshenv
    print_success "Backed up old .zshenv and created symlink"
fi

if [[ -L ~/.zshrc ]]; then
    # If it's a symlink, remove and recreate it
    rm ~/.zshrc
    ln -sf ~/.config/zsh/.zshrc ~/.zshrc
    print_success "Updated .zshrc symlink"
elif [[ ! -f ~/.zshrc ]]; then
    ln -sf ~/.config/zsh/.zshrc ~/.zshrc
    print_success "Created .zshrc symlink"
else
    print_warning ".zshrc exists but is not a symlink. Backing up and creating symlink..."
    mv ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
    ln -sf ~/.config/zsh/.zshrc ~/.zshrc
    print_success "Backed up old .zshrc and created symlink"
fi

# Create .zprivate if it doesn't exist
if [[ ! -f ~/.config/zsh/.zprivate ]]; then
    touch ~/.config/zsh/.zprivate
    print_success "Created .zprivate file for personal configs"
else
    print_success ".zprivate already exists"
fi

# Set Zsh as default shell
print_step "Setting Zsh as default shell..."
if [[ "$SHELL" != *"zsh"* ]]; then
    chsh -s "$(which zsh)"
    print_success "Zsh set as default shell"
else
    print_success "Zsh already default shell"
fi

# Setup NVM directory
print_step "Setting up NVM..."
if [[ ! -d ~/.nvm ]]; then
    mkdir -p ~/.nvm
    print_success "Created NVM directory"
else
    print_success "NVM directory already exists"
fi

# Install pyenv + pyenv-virtualenv if missing.
# NOTE: on this machine pyenv is git-installed under ~/.pyenv (not Homebrew), so it is
# intentionally NOT in the Brewfile -- a plain `brew bundle dump` cannot capture it.
print_step "Checking pyenv installation..."
if ! command_exists pyenv; then
    print_warning "pyenv not found. Installing via git..."
    git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    git clone https://github.com/pyenv/pyenv-virtualenv.git "$(pyenv root)/plugins/pyenv-virtualenv"
    print_success "pyenv + pyenv-virtualenv installed"
else
    print_success "pyenv already installed"
fi

# Setup pyenv-pyright plugin
print_step "Installing pyenv-pyright plugin..."
if [[ ! -d $(pyenv root)/plugins/pyenv-pyright ]]; then
    git clone https://github.com/alefpereira/pyenv-pyright.git "$(pyenv root)/plugins/pyenv-pyright"
    print_success "pyenv-pyright installed"
else
    print_success "pyenv-pyright already installed"
fi

# Setup Python for Neovim
print_step "Setting up Python for Neovim..."
if ! pyenv versions | grep -q "neovim3"; then
    print_warning "Installing Python 3.9.7 for Neovim (this may take a few minutes)..."
    pyenv install -s 3.9.7
    pyenv virtualenv 3.9.7 neovim3
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
    pyenv activate neovim3
    pip install pynvim
    pyenv deactivate
    print_success "Neovim Python environment created"
else
    print_success "Neovim Python environment already exists"
fi

# Setup password manager
print_step "Setting up password manager..."
if [[ -d ~/.config/pwmanager ]]; then
    cd ~/.config/pwmanager
    bash install.sh
    print_success "Password manager installed"
else
    print_warning "Password manager directory not found, skipping..."
fi

# Setup fzf
print_step "Setting up fzf..."
if [[ ! -f ~/.fzf.zsh ]]; then
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc
    print_success "fzf configured"
else
    print_success "fzf already configured"
fi

# Setup Atuin
print_step "Setting up Atuin..."
if [[ ! -d ~/.atuin ]]; then
    atuin import auto
    print_success "Atuin configured"
else
    print_success "Atuin already configured"
fi

# Setup iTerm2 CMD layer (tmux Dynamic Profile)
# Symlinks the dynamic profile so Cmd+<key> replays tmux prefix actions in iTerm2.
# Selecting it as the default profile is a GUI step (see "Next steps" below).
print_step "Setting up iTerm2 CMD layer profile..."
PROFILE_SRC="$HOME/.config/tmux/iterm2-cmd-layer.json"
DYNAMIC_PROFILES="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
PROFILE_LINK="$DYNAMIC_PROFILES/tmux-cmd-layer.json"
if [[ ! -f "$PROFILE_SRC" ]]; then
    print_warning "tmux CMD-layer profile not found at $PROFILE_SRC, skipping..."
else
    mkdir -p "$DYNAMIC_PROFILES"
    if [[ -L "$PROFILE_LINK" ]]; then
        rm "$PROFILE_LINK"
        ln -sf "$PROFILE_SRC" "$PROFILE_LINK"
        print_success "Updated iTerm2 CMD-layer profile symlink"
    elif [[ ! -e "$PROFILE_LINK" ]]; then
        ln -sf "$PROFILE_SRC" "$PROFILE_LINK"
        print_success "Created iTerm2 CMD-layer profile symlink"
    else
        print_warning "$PROFILE_LINK exists but is not a symlink. Backing up and creating symlink..."
        mv "$PROFILE_LINK" "$PROFILE_LINK.backup.$(date +%Y%m%d_%H%M%S)"
        ln -sf "$PROFILE_SRC" "$PROFILE_LINK"
        print_success "Backed up old profile and created symlink"
    fi
fi

echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════╗"
echo "║     Setup Complete! 🎉                ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo ""
print_step "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Open Neovim and let plugins install: nvim"
echo "  3. Configure Ghostty as your default terminal"
echo "  4. Add your secrets to ~/.config/zsh/.zprivate"
echo "  5. Activate the iTerm2 CMD layer: Settings > Profiles > 'tmux (CMD layer)' > Other Actions > Set as Default, then reopen iTerm2"
echo ""
print_warning "You may need to log out and back in for all changes to take effect."
echo ""

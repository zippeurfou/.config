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

# Install core tools
print_step "Installing core tools..."

packages=(
    "zsh"
    "starship"
    "fzf"
    "direnv"
    "atuin"
    "eza"
    "ripgrep"
    "bat"
    "fd"
    "neovim"
    "nvm"
    "uv"
    "pyenv"
    "pyenv-virtualenv"
    "zsh-autocomplete"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "zsh-completions"
)

casks=(
    "ghostty"
    "iterm2"
    "nikitabobko/tap/aerospace"
    "font-hack-nerd-font"
)

for package in "${packages[@]}"; do
    if brew list "$package" &>/dev/null; then
        print_success "$package already installed"
    else
        print_step "Installing $package..."
        brew install "$package"
    fi
done

for cask in "${casks[@]}"; do
    cask_name="${cask##*/}"
    if brew list --cask "$cask_name" &>/dev/null 2>&1; then
        print_success "$cask_name already installed"
    else
        print_step "Installing $cask_name..."
        brew install --cask "$cask"
    fi
done

# Install JankyBorders
print_step "Installing JankyBorders..."
if ! command_exists borders; then
    brew tap FelixKratz/formulae
    brew install borders
    print_success "JankyBorders installed"
else
    print_success "JankyBorders already installed"
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
echo ""
print_warning "You may need to log out and back in for all changes to take effect."
echo ""

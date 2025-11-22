# 🚀 dotfiles

> My personal macOS development environment configuration.

## 🎯 What's Inside

- **Shell**: Zsh with vim keybindings, starship prompt
- **Terminal**: Ghostty with Tokyo Night theme as well as iterm2 support
- **Editor**: Neovim with lazy.nvim and custom plugins
- **Window Manager**: AeroSpace (tiling WM) + JankyBorders
- **Tools**: fzf, eza, atuin, direnv...

## ⚡ Quick Start

# Run setup
./setup.sh
```

That's it! Your environment is ready. 🎉

## 📦 Manual Installation

### 1. Prerequisites

Install Homebrew (if not already installed):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Core Tools

```bash
# Terminal & shell
brew install --cask ghostty iterm2
brew install zsh starship fzf direnv atuin

# Better tools
brew install eza ripgrep bat fd

# Zsh plugins
brew install zsh-autocomplete zsh-autosuggestions zsh-syntax-highlighting zsh-completions

# Window management
brew install --cask nikitabobko/tap/aerospace
brew tap FelixKratz/formulae
brew install borders

# Fonts
brew install --cask font-hack-nerd-font

# Editor
brew install neovim

# Node version manager
brew install nvm
mkdir -p ~/.nvm

# Python environment
brew install pyenv pyenv-virtualenv uv
git clone https://github.com/alefpereira/pyenv-pyright.git $(pyenv root)/plugins/pyenv-pyright

```

> [!NOTE]
> I need to change to uv only here

### 3. Setup Python for Neovim

```bash
# Python 3 (for Neovim)
pyenv install 3.9.7
pyenv virtualenv 3.9.7 neovim3
pyenv activate neovim3
pip install pynvim
```

### 4. Configure Shell

Create the symlink for zsh environment:

```bash
ln -sf ~/.config/zsh/symlink/.zshenv ~/.zshenv
ln -sf ~/.config/zsh/.zshrc ~/.zshrc
```

Create a `.zprivate` file for your personal/secret configs:

```bash
touch ~/.config/zsh/.zprivate
```

### 5. Configure Terminal

Set Ghostty as your default terminal and restart it. The config will be automatically picked up from `~/.config/ghostty/config`.

### 6. Install Password Manager

> [!NOTE]
> I am not a fan of this, I need to remove it later. I think keyring should be enough.

```bash
cd ~/.config/pwmanager
bash install.sh
```

### 7. Setup AeroSpace & Borders

AeroSpace and JankyBorders will auto-start on login (configured in `aerospace.toml`). To start them immediately:

```bash
aerospace --config ~/.config/aerospace/aerospace.toml &
borders &
```

### 8. Neovim Setup

Open Neovim and let lazy.nvim install all plugins:

```bash
nvim
```

Press `:Lazy` to see plugin status.

## 🔑 Key Features

### Shell Aliases

- `ls` → eza with icons and git status
- `vim`/`nvim`/`v` → smart nvim launcher with virtualenv support
- `oc` → opencode setup with AWS SSO integration
- `d` → directory stack viewer (use `1-9` to jump)
- `create_project <name> <python-version>` → create GitHub repo with Python setup

### Ghostty Keybindings

All keybindings use `cmd+g` prefix:

- `cmd+g > n` → new window
- `cmd+g > c` → new tab
- `cmd+g > [/]` → switch tabs
- `cmd+g > \` → split right
- `cmd+g > -` → split down
- `cmd+g > h/j/k/l` → navigate splits (vim style)
- `cmd+g > m` → maximize split
- `cmd+g > r` → reload config

### Zsh Vi Mode

Vi keybindings enabled with:
- `v` in command mode → edit in $EDITOR
- `da"`, `ci{`, etc. → text objects work
- `hjkl` in completion menu
- Fast mode switching (10ms timeout)

## 🛠️ Structure

```
~/.config/
├── aerospace/         # Window manager config
├── borders/           # Window border styling
├── ghostty/           # Terminal config
├── nvim/              # Neovim config (see nvim/Readme.md)
├── opencode/          # OpenCode AI config & skills
├── pwmanager/         # Password management utility
├── zsh/               # Zsh config & plugins
│   ├── plugins/       # Custom plugins
│   ├── symlink/       # Files to symlink to ~
│   ├── .zalias        # Aliases & functions
│   └── .zshrc         # Main config
└── starship.toml      # Prompt config
```

## 🔒 Private Config

The `.zprivate` file (ignored by git) is for:
- API tokens
- Company-specific configs  
- Personal secrets

Example `.zprivate`:

```bash
export GITHUB_TOKEN="ghp_xxxxx"
export OPENAI_API_KEY="sk-xxxxx"
# Any other secrets...
```

## 📝 Notes

- **OpenCode**: The `opencode/` directory contains AI agent configurations and custom skills. Run `oc` to start with auto AWS SSO auth.
- **Neovim**: See `nvim/Readme.md` for detailed Neovim setup instructions.
- **AeroSpace**: See the [AeroSpace guide](https://nikitabobko.github.io/AeroSpace/guide) for window management shortcuts.

## 📄 License

MIT License - feel free to use and modify!

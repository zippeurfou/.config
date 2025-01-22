# Password Manager

A simple yet powerful password management utility that seamlessly integrates with your system's keyring and environment variables. Perfect for both command-line usage and Python applications.

## Features

- Secure password storage using system keyring
- Environment variable fallback
- Command-line interface with auto-completion
- Python library integration
- Cross-environment compatibility (works with pyenv)

## Installation


1. Run the installation script:
```bash
cd ~/.config/pwmanager
bash install.sh
```

2. Add to your shell configuration (`~/.zshrc` or `~/.bashrc`):
```bash
# Enable shell completion
source ~/.local/share/bash-completion/completions/password
```

## Usage

### Command Line Interface

```bash
# Store a password
password set "service_name" "your_secret_password"

# Retrieve a password
password get "service_name"

# Delete a password
password delete "service_name"
```

### Python Integration

```python
from pwmanager import get_password

# Will try keyring first, then fall back to environment variable
password = get_password("service_name")
```

### Password Resolution Order

1. System keyring storage
2. Environment variable (using uppercase service name)
   - Example: `service_name` will look for `SERVICE_NAME` in env variables
3. Raises `KeyError` if password is not found in either location

## Requirements

- Python 3.x
- `keyring` package
- Unix-like environment (macOS, Linux)

## Installation in Python Environments

The tool automatically works with any Python environment. If you're using pyenv:

```bash
# The installer automatically adds the library path to all pyenv environments
# Just install keyring in your environment
pyenv activate your-environment
pip install keyring
```

## Directory Structure

```
~/.config/pwmanager/
├── bin/
│   └── password           # CLI executable
├── lib/
│   └── pwmanager/        # Python package
│       └── __init__.py
└── shell/
    └── completion/       # Shell completion
        └── password
```

## Security Considerations

- Passwords are stored securely in your system's keyring
- Environment variables are used as fallback only
- No plain-text storage of sensitive information
- Uses your system's security mechanisms

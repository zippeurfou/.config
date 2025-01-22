import os
import warnings

import keyring


def get_password(service_name: str) -> str:
    """Get password from keyring or environment variable."""
    password = keyring.get_password("system", service_name)

    if password is None:
        env_var = service_name.upper()
        password = os.environ.get(env_var)
        if password is not None:
            warnings.warn(f"Using environment variable {env_var} instead of keyring")
        else:
            raise KeyError(f"No password found for {service_name}")

    return password


def set_password(service_name: str, password: str) -> None:
    """Set password in keyring."""
    keyring.set_password("system", service_name, password)


def delete_password(service_name: str) -> None:
    """Delete password from keyring."""
    try:
        keyring.delete_password("system", service_name)
    except:
        raise KeyError(f"No password found for {service_name}")

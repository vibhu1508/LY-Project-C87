"""
Dedicated file-based storage for bootstrap credentials.

HIVE_CREDENTIAL_KEY -> ~/.teamagents/secrets/credential_key  (plain text, chmod 600)

Boot order:
  1. load_credential_key()   -- reads/generates the Fernet key, sets os.environ
"""

from __future__ import annotations

import logging
import os
import stat
from pathlib import Path

logger = logging.getLogger(__name__)

CREDENTIAL_KEY_PATH = Path.home() / ".teamagents" / "secrets" / "credential_key"
CREDENTIAL_KEY_ENV_VAR = "HIVE_CREDENTIAL_KEY"


# ---------------------------------------------------------------------------
# HIVE_CREDENTIAL_KEY
# ---------------------------------------------------------------------------


def load_credential_key() -> str | None:
    """Load HIVE_CREDENTIAL_KEY with priority: env > file > shell config.

    Sets ``os.environ["HIVE_CREDENTIAL_KEY"]`` as a side-effect when found.
    Returns the key string, or ``None`` if unavailable everywhere.
    """
    # 1. Already in environment (set by parent process, CI, Windows Registry, etc.)
    key = os.environ.get(CREDENTIAL_KEY_ENV_VAR)
    if key:
        return key

    # 2. Dedicated secrets file
    key = _read_credential_key_file()
    if key:
        os.environ[CREDENTIAL_KEY_ENV_VAR] = key
        return key

    # 3. Shell config fallback (backward compat for old installs)
    key = _read_from_shell_config(CREDENTIAL_KEY_ENV_VAR)
    if key:
        os.environ[CREDENTIAL_KEY_ENV_VAR] = key
        return key

    return None


def save_credential_key(key: str) -> Path:
    """Save HIVE_CREDENTIAL_KEY to ``~/.teamagents/secrets/credential_key``.

    Creates parent dirs with mode 700, writes the file with mode 600.
    Also sets ``os.environ["HIVE_CREDENTIAL_KEY"]``.

    Returns:
        The path that was written.
    """
    path = CREDENTIAL_KEY_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        # Restrict the secrets directory itself (Unix)
        path.parent.chmod(stat.S_IRWXU)  # 0o700
    except Exception:
        pass

    path.write_text(key, encoding="utf-8")
    try:
        path.chmod(stat.S_IRUSR | stat.S_IWUSR)  # 0o600
    except Exception:
        pass

    os.environ[CREDENTIAL_KEY_ENV_VAR] = key
    return path


def generate_and_save_credential_key() -> str:
    """Generate a new Fernet key and persist it to ``~/.teamagents/secrets/credential_key``.

    Returns:
        The generated key string.
    """
    from cryptography.fernet import Fernet

    key = Fernet.generate_key().decode()
    save_credential_key(key)
    return key


# ---------------------------------------------------------------------------
# Deprecated Aden Stubs (no-op)
# ---------------------------------------------------------------------------


def load_aden_api_key() -> str | None:
    """Deprecated stub: Aden service has been removed."""
    return None


def save_aden_api_key(key: str) -> None:
    """Deprecated stub: Aden service has been removed."""
    pass


def delete_aden_api_key() -> bool:
    """Deprecated stub: Aden service has been removed."""
    return False


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------


def _read_credential_key_file() -> str | None:
    """Read the credential key from ``~/.teamagents/secrets/credential_key``."""
    try:
        if CREDENTIAL_KEY_PATH.is_file():
            value = CREDENTIAL_KEY_PATH.read_text(encoding="utf-8").strip()
            if value:
                return value
    except (FileNotFoundError, PermissionError) as e:
        logger.debug("Could not read %s: %s", CREDENTIAL_KEY_PATH, e)
    except Exception:
        logger.warning("Unexpected error reading %s", CREDENTIAL_KEY_PATH, exc_info=True)
    return None


def _read_from_shell_config(env_var: str) -> str | None:
    """Fallback: read an env var from shell config files."""
    home = Path.home()
    for rc in [home / ".zshrc", home / ".bashrc", home / ".bash_profile"]:
        if rc.is_file():
            try:
                for line in rc.read_text(encoding="utf-8", errors="ignore").splitlines():
                    line = line.strip()
                    if line.startswith(f"export {env_var}=") or line.startswith(f"{env_var}="):
                        val = line.split("=", 1)[1].strip("'\"")
                        if val:
                            return val
            except Exception:
                pass
    return None

"""
Centralized credential management for Aden Tools.

Provides agent-aware validation, clear error messages, and testability.

Philosophy: Google Strictness + Apple UX
- Validate credentials before running an agent (fail-fast at the right boundary)
- Guided error messages with clear next steps

Usage:
    from aden_tools.credentials import CredentialStoreAdapter
    from framework.credentials import CredentialStore

    # With encrypted storage (production)
    store = CredentialStore.with_encrypted_storage()  # defaults to ~/.teamagents/credentials
    credentials = CredentialStoreAdapter(store)

    # With composite storage (encrypted primary + env fallback)
    credentials = CredentialStoreAdapter.default()

    # In agent runner (validate at agent load time)
    credentials.validate_for_tools(["web_search", "file_read"])

    # In tools
    api_key = credentials.get("brave_search")

    # In tests
    creds = CredentialStoreAdapter.for_testing({"brave_search": "test-key"})

    # Template resolution
    headers = credentials.resolve_headers({
        "Authorization": "Bearer {{github_oauth.access_token}}"
    })
"""

from .base import CredentialError, CredentialSpec
from .browser import get_aden_auth_url, get_aden_setup_url, open_browser
from .discord import DISCORD_CREDENTIALS
from .email import EMAIL_CREDENTIALS
from .gcp_vision import GCP_VISION_CREDENTIALS
from .github import GITHUB_CREDENTIALS
from .health_check import (
    HealthCheckResult,
    check_credential_health,
)
from .huggingface import HUGGINGFACE_CREDENTIALS
from .n8n import N8N_CREDENTIALS
from .news import NEWS_CREDENTIALS
from .notion import NOTION_CREDENTIALS
from .obsidian import OBSIDIAN_CREDENTIALS
from .pushover import PUSHOVER_CREDENTIALS
from .search import SEARCH_CREDENTIALS
from .shell_config import (
    add_env_var_to_shell_config,
    detect_shell,
    get_shell_config_path,
    get_shell_source_command,
)
from .store_adapter import CredentialStoreAdapter
from .telegram import TELEGRAM_CREDENTIALS
from .youtube import YOUTUBE_CREDENTIALS
from .zoom import ZOOM_CREDENTIALS

# Merged registry of all credentials
CREDENTIAL_SPECS = {
    **DISCORD_CREDENTIALS,
    **EMAIL_CREDENTIALS,
    **GCP_VISION_CREDENTIALS,
    **GITHUB_CREDENTIALS,
    **HUGGINGFACE_CREDENTIALS,
    **N8N_CREDENTIALS,
    **NEWS_CREDENTIALS,
    **NOTION_CREDENTIALS,
    **OBSIDIAN_CREDENTIALS,
    **PUSHOVER_CREDENTIALS,
    **SEARCH_CREDENTIALS,
    **TELEGRAM_CREDENTIALS,
    **YOUTUBE_CREDENTIALS,
    **ZOOM_CREDENTIALS,
}

__all__ = [
    # Core classes
    "CredentialSpec",
    "CredentialStoreAdapter",
    "CredentialError",
    # Health check utilities
    "HealthCheckResult",
    "check_credential_health",
    # Browser utilities for OAuth2 flows
    "open_browser",
    "get_aden_auth_url",
    "get_aden_setup_url",
    # Shell config utilities
    "detect_shell",
    "get_shell_config_path",
    "get_shell_source_command",
    "add_env_var_to_shell_config",
    # Merged registry
    "CREDENTIAL_SPECS",
    # Category registries
    "DISCORD_CREDENTIALS",
    "EMAIL_CREDENTIALS",
    "GCP_VISION_CREDENTIALS",
    "GITHUB_CREDENTIALS",
    "HUGGINGFACE_CREDENTIALS",
    "N8N_CREDENTIALS",
    "NEWS_CREDENTIALS",
    "NOTION_CREDENTIALS",
    "OBSIDIAN_CREDENTIALS",
    "PUSHOVER_CREDENTIALS",
    "SEARCH_CREDENTIALS",
    "TELEGRAM_CREDENTIALS",
    "YOUTUBE_CREDENTIALS",
    "ZOOM_CREDENTIALS",
]

"""
Aden Credential Sync - Deprecated Module.

External Aden platform dependency has been removed in favor of local encrypted storage.
"""

from .client import (
    AdenAuthenticationError,
    AdenClientConfig,
    AdenClientError,
    AdenCredentialClient,
    AdenCredentialResponse,
    AdenIntegrationInfo,
    AdenNotFoundError,
    AdenRateLimitError,
    AdenRefreshError,
)
from .provider import AdenSyncProvider
from .storage import AdenCachedStorage

__all__ = [
    # Client
    "AdenCredentialClient",
    "AdenClientConfig",
    "AdenCredentialResponse",
    "AdenIntegrationInfo",
    # Client errors
    "AdenClientError",
    "AdenAuthenticationError",
    "AdenNotFoundError",
    "AdenRateLimitError",
    "AdenRefreshError",
    # Provider
    "AdenSyncProvider",
    # Storage
    "AdenCachedStorage",
]

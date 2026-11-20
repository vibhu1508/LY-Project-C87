"""
Aden Credential Sync Provider - Deprecated Stub.

The external Aden service dependency has been removed.
These stubs exist only to preserve backwards compatibility for imports.
"""

from __future__ import annotations

import logging
from typing import Any

from framework.credentials.provider import CredentialProvider
from .client import AdenCredentialClient

logger = logging.getLogger(__name__)


class AdenSyncProvider(CredentialProvider):
    """Deprecated stub: AdenSyncProvider is no longer active."""

    def __init__(self, client: AdenCredentialClient | None = None, **kwargs: Any):
        super().__init__(name="aden_sync", **kwargs)
        self._client = client

    def get_credential(self, credential_id: str) -> Any:
        return None

    def refresh_credential(self, credential_id: str) -> Any:
        return None

    def sync_all(self, store: Any) -> int:
        return 0

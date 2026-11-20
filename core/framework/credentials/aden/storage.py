"""
Aden Cached Storage - Deprecated Stub.

The external Aden service dependency has been removed.
These stubs exist only to preserve backwards compatibility for imports.
"""

from __future__ import annotations

import logging
from typing import Any

from framework.credentials.storage import CredentialStorage, EncryptedFileStorage
from .provider import AdenSyncProvider

logger = logging.getLogger(__name__)


class AdenCachedStorage(CredentialStorage):
    """Deprecated stub: AdenCachedStorage delegates purely to local storage."""

    def __init__(
        self,
        local_storage: CredentialStorage | None = None,
        aden_provider: AdenSyncProvider | None = None,
        **kwargs: Any,
    ):
        self._local = local_storage or EncryptedFileStorage()
        self._aden_provider = aden_provider

    def save(self, credential: Any) -> None:
        self._local.save(credential)

    def load(self, credential_id: str) -> Any:
        return self._local.load(credential_id)

    def delete(self, credential_id: str) -> bool:
        return self._local.delete(credential_id)

    def list_all(self) -> list[str]:
        return self._local.list_all()

    def exists(self, credential_id: str) -> bool:
        return self._local.exists(credential_id)

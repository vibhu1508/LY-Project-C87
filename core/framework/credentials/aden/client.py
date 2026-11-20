"""
Aden Credential Client - Deprecated Stub.

The external Aden service dependency has been removed.
These stubs exist only to preserve backwards compatibility for imports.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime

logger = logging.getLogger(__name__)


class AdenClientError(Exception):
    """Base exception for Aden client errors."""
    pass


class AdenAuthenticationError(AdenClientError):
    """Raised when API key is invalid or revoked."""
    pass


class AdenNotFoundError(AdenClientError):
    """Raised when integration is not found."""
    pass


class AdenRefreshError(AdenClientError):
    """Raised when token refresh fails."""
    def __init__(
        self,
        message: str = "Aden sync is deprecated and removed.",
        requires_reauthorization: bool = False,
        reauthorization_url: str | None = None,
    ):
        super().__init__(message)
        self.requires_reauthorization = requires_reauthorization
        self.reauthorization_url = reauthorization_url


class AdenRateLimitError(AdenClientError):
    """Raised when rate limited."""
    def __init__(self, message: str = "Rate limit error", retry_after: int = 60):
        super().__init__(message)
        self.retry_after = retry_after


@dataclass
class AdenClientConfig:
    """Configuration stub for Aden API client."""
    base_url: str = "https://api.adenhq.com"
    api_key: str | None = None
    tenant_id: str | None = None
    timeout: float = 30.0
    retry_attempts: int = 3
    retry_delay: float = 1.0


@dataclass
class AdenIntegrationInfo:
    """Stub integration info."""
    integration_id: str = ""
    provider: str = ""
    alias: str = ""
    status: str = "inactive"
    email: str = ""
    expires_at: datetime | None = None


@dataclass
class AdenCredentialResponse:
    """Stub credential response."""
    access_token: str = ""
    token_type: str = "Bearer"
    expires_in: int = 0
    expires_at: datetime | None = None
    integration_id: str = ""
    provider: str = ""
    alias: str = ""
    status: str = "inactive"
    raw_response: dict | None = None


class AdenCredentialClient:
    """Deprecated stub: Aden client is no longer active."""

    def __init__(self, config: AdenClientConfig | None = None):
        self.config = config or AdenClientConfig()

    def list_integrations(self) -> list[AdenIntegrationInfo]:
        return []

    def get_credential(self, integration_id: str) -> AdenCredentialResponse:
        raise NotImplementedError("Aden service is removed. Use local credential storage.")

    def refresh_credential(self, integration_id: str) -> AdenCredentialResponse:
        raise NotImplementedError("Aden service is removed. Use local credential storage.")

    def close(self) -> None:
        pass

    def __enter__(self) -> AdenCredentialClient:
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()

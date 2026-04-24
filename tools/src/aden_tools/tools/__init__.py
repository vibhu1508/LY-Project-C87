"""
Aden Tools - Tool implementations for FastMCP.

Usage:
    from fastmcp import FastMCP
    from aden_tools.tools import register_all_tools
    from aden_tools.credentials import CredentialStoreAdapter

    mcp = FastMCP("my-server")
    credentials = CredentialStoreAdapter.default()
    register_all_tools(mcp, credentials=credentials)

    # To also load unverified (community/new) integrations:
    register_all_tools(mcp, credentials=credentials, include_unverified=True)
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from fastmcp import FastMCP

if TYPE_CHECKING:
    from aden_tools.credentials import CredentialStoreAdapter

# ---------------------------------------------------------------------------
# Verified tools (stable, on main)
# ---------------------------------------------------------------------------
from .arxiv_tool import register_tools as register_arxiv
from .calendar_tool import register_tools as register_calendar
from .csv_tool import register_tools as register_csv
from .discord_tool import register_tools as register_discord
from .dns_security_scanner import register_tools as register_dns_security_scanner
from .email_tool import register_tools as register_email
from .excel_tool import register_tools as register_excel

# File system toolkits
from .file_system_toolkits.apply_diff import register_tools as register_apply_diff
from .file_system_toolkits.apply_patch import register_tools as register_apply_patch
from .file_system_toolkits.data_tools import register_tools as register_data_tools
from .file_system_toolkits.execute_command_tool import (
    register_tools as register_execute_command,
)
from .file_system_toolkits.grep_search import register_tools as register_grep_search
from .file_system_toolkits.hashline_edit import register_tools as register_hashline_edit
from .file_system_toolkits.list_dir import register_tools as register_list_dir
from .file_system_toolkits.replace_file_content import (
    register_tools as register_replace_file_content,
)

from .github_tool import register_tools as register_github
from .gmail_tool import register_tools as register_gmail
from .google_docs_tool import register_tools as register_google_docs
from .google_sheets_tool import register_tools as register_google_sheets
from .http_headers_scanner import register_tools as register_http_headers_scanner
from .news_tool import register_tools as register_news
from .pdf_read_tool import register_tools as register_pdf_read
from .risk_scorer import register_tools as register_risk_scorer
from .runtime_logs_tool import register_tools as register_runtime_logs
from .tech_stack_detector import register_tools as register_tech_stack_detector
from .telegram_tool import register_tools as register_telegram
from .time_tool import register_tools as register_time
from .vision_tool import register_tools as register_vision
from .web_scrape_tool import register_tools as register_web_scrape
from .web_search_tool import register_tools as register_web_search
from .wikipedia_tool import register_tools as register_wikipedia


# ---------------------------------------------------------------------------
# Unverified tools (new integrations, pending review)
# ---------------------------------------------------------------------------
from .duckduckgo_tool import register_tools as register_duckduckgo
from .huggingface_tool import register_tools as register_huggingface
from .mssql_tool import register_tools as register_mssql
from .n8n_tool import register_tools as register_n8n
from .notion_tool import register_tools as register_notion
from .obsidian_tool import register_tools as register_obsidian
from .pushover_tool import register_tools as register_pushover
from .youtube_tool import register_tools as register_youtube
from .youtube_transcript_tool import register_tools as register_youtube_transcript
from .zoom_tool import register_tools as register_zoom


def _register_verified(
    mcp: FastMCP,
    credentials: CredentialStoreAdapter | None = None,
) -> None:
    """Register verified (stable) tools."""
    # --- No credentials ---
    register_web_scrape(mcp)
    register_pdf_read(mcp)
    register_time(mcp)
    register_runtime_logs(mcp)
    register_wikipedia(mcp)
    register_arxiv(mcp)

    # --- File system toolkits ---
    register_list_dir(mcp)
    register_replace_file_content(mcp)
    register_apply_diff(mcp)
    register_apply_patch(mcp)
    register_grep_search(mcp)
    register_hashline_edit(mcp)
    register_execute_command(mcp)
    register_data_tools(mcp)
    register_csv(mcp)
    register_excel(mcp)

    # --- Security scanning (no credentials) ---
    register_http_headers_scanner(mcp)
    register_dns_security_scanner(mcp)
    register_tech_stack_detector(mcp)
    register_risk_scorer(mcp)

    # --- Credentials required ---
    register_web_search(mcp, credentials=credentials)
    register_github(mcp, credentials=credentials)
    register_email(mcp, credentials=credentials)
    register_gmail(mcp, credentials=credentials)
    register_calendar(mcp, credentials=credentials)
    register_discord(mcp, credentials=credentials)
    register_news(mcp, credentials=credentials)
    register_telegram(mcp, credentials=credentials)
    register_google_docs(mcp, credentials=credentials)
    register_google_sheets(mcp, credentials=credentials)
    register_vision(mcp, credentials=credentials)


def _register_unverified(
    mcp: FastMCP,
    credentials: CredentialStoreAdapter | None = None,
) -> None:
    """Register unverified (new/community) tools."""
    # --- No credentials ---
    register_duckduckgo(mcp)
    register_youtube_transcript(mcp)

    # --- Credentials required ---
    register_huggingface(mcp, credentials=credentials)
    register_mssql(mcp, credentials=credentials)
    register_n8n(mcp, credentials=credentials)
    register_notion(mcp, credentials=credentials)
    register_obsidian(mcp, credentials=credentials)
    register_pushover(mcp, credentials=credentials)
    register_youtube(mcp, credentials=credentials)
    register_zoom(mcp, credentials=credentials)


def register_all_tools(
    mcp: FastMCP,
    credentials: CredentialStoreAdapter | None = None,
    include_unverified: bool = False,
) -> list[str]:
    """
    Register all tools with a FastMCP server.

    Args:
        mcp: FastMCP server instance
        credentials: Optional CredentialStoreAdapter instance.
                     If not provided, tools fall back to direct os.getenv() calls.
        include_unverified: If True, also register unverified/community tools.
                           Defaults to False for production safety.

    Returns:
        List of registered tool names
    """
    _register_verified(mcp, credentials=credentials)

    if include_unverified:
        _register_unverified(mcp, credentials=credentials)

    return list(mcp._tool_manager._tools.keys())


__all__ = ["register_all_tools"]

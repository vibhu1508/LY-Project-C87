#!/usr/bin/env bash
# Wrapper script for the TeamAgents CLI (macOS / Linux).
# Runs the `teamagents` command inside the project's uv-managed virtualenv.
#
# This is the POSIX counterpart of teamagents.ps1. quickstart.sh symlinks
# ~/.local/bin/teamagents to this file, so it must keep working when invoked
# through that symlink from any working directory — hence the path resolution
# below rather than a plain dirname of "$0".

set -euo pipefail

# ── Resolve this script's real location ─────────────────────────────
# BSD readlink has no portable -f, so walk the symlink chain by hand.
# Relative link targets resolve against the directory holding the link.

_resolve_path() {
    local target="$1" link_dir
    while [ -L "$target" ]; do
        link_dir="$( cd -P "$( dirname "$target" )" && pwd )"
        target="$( readlink "$target" )"
        case "$target" in
            /*) ;;
            *) target="$link_dir/$target" ;;
        esac
    done
    printf '%s/%s\n' "$( cd -P "$( dirname "$target" )" && pwd )" "$( basename "$target" )"
}

SCRIPT_PATH="$( _resolve_path "${BASH_SOURCE[0]}" )"
PROJECT_DIR="$( dirname "$SCRIPT_PATH" )"

# ── Validate the project layout ─────────────────────────────────────

if [ ! -f "$PROJECT_DIR/pyproject.toml" ] || [ ! -d "$PROJECT_DIR/core" ]; then
    echo "teamagents: not a valid TeamAgents project directory: $PROJECT_DIR" >&2
    exit 1
fi

if [ ! -d "$PROJECT_DIR/.venv" ]; then
    echo "teamagents: virtual environment not found in $PROJECT_DIR" >&2
    echo "            Run ./quickstart.sh first to set up the project." >&2
    exit 1
fi

# ── Ensure uv is available ──────────────────────────────────────────
# uv installs to ~/.local/bin, which login shells pick up but cron jobs,
# GUI-launched apps and some IDE terminals do not.

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

if ! command -v uv &> /dev/null; then
    echo "teamagents: uv is not installed or is not on PATH." >&2
    echo "            Run ./quickstart.sh first, or install it from https://astral.sh/uv/" >&2
    exit 1
fi

# ── Load the credential-store key ───────────────────────────────────
# quickstart.sh writes this to a chmod-600 file. Load it when the current
# shell has not exported it, so encrypted credentials stay readable.

if [ -z "${HIVE_CREDENTIAL_KEY:-}" ]; then
    _key_file="$HOME/.teamagents/secrets/credential_key"
    if [ -r "$_key_file" ]; then
        HIVE_CREDENTIAL_KEY="$( cat "$_key_file" )"
        export HIVE_CREDENTIAL_KEY
    fi
fi

# ── Warn about an LLM config that will not take effect ──────────────
# The framework silently falls back to its default model when the configured
# provider is outside the allowlist (subscription modes included), which shows
# up much later as an authentication failure. Surface it here instead.
# Non-fatal by design: any error in this block is ignored.

_llm_warning="$(
    python3 - "$PROJECT_DIR" <<'PY' 2>/dev/null || true
import json
import os
import pathlib
import re
import sys

project_dir = pathlib.Path(sys.argv[1])
config_path = pathlib.Path.home() / ".teamagents" / "configuration.json"
if not config_path.is_file():
    raise SystemExit

llm = json.loads(config_path.read_text(encoding="utf-8-sig")).get("llm") or {}
if not isinstance(llm, dict):
    raise SystemExit

# Read the allowlist out of the framework itself so this cannot drift.
source = (project_dir / "core" / "framework" / "config.py").read_text(encoding="utf-8")
match = re.search(r"ALLOWED_LLM_PROVIDERS\s*=\s*frozenset\(\{([^}]*)\}\)", source)
allowed = set(re.findall(r'"([^"]+)"', match.group(1))) if match else set()

subscription = next(
    (flag for flag in llm if flag.startswith("use_") and flag.endswith("_subscription") and llm[flag]),
    None,
)
provider = str(llm.get("provider", "")).strip().lower()

if subscription:
    print(f"'{subscription}' is set, but subscription modes are not supported by this build.")
elif allowed and provider and provider not in allowed:
    print(f"provider '{provider}' is not supported by this build.")
else:
    env_var = str(llm.get("api_key_env_var", "")).strip()
    if env_var and not os.environ.get(env_var):
        print(f"{env_var} is not set in this shell.")
        print(f"HINT:Open a new terminal, or run: source ~/.zshrc")
PY
)"

if [ -n "$_llm_warning" ]; then
    while IFS= read -r _line; do
        case "$_line" in
            HINT:*) echo "            ${_line#HINT:}" >&2 ;;
            *) echo "teamagents: $_line" >&2 ;;
        esac
    done <<< "$_llm_warning"
    echo "            Re-run ./quickstart.sh to pick a supported provider." >&2
    echo "" >&2
fi

# ── Run the TeamAgents CLI ──────────────────────────────────────────
# uv resolves the venv from the project directory, so run from there.

cd "$PROJECT_DIR"
exec uv run teamagents "$@"

"""Runtime configuration for Queen agent."""

import json
from dataclasses import dataclass, field
from pathlib import Path


def _load_preferred_model() -> str:
    """Load preferred model from ~/.teamagents/configuration.json."""
    config_path = Path.home() / ".teamagents" / "configuration.json"
    if config_path.exists():
        try:
            with open(config_path, encoding="utf-8") as f:
                config = json.load(f)
            llm = config.get("llm", {})
            if llm.get("provider") and llm.get("model"):
                return f"{llm['provider']}/{llm['model']}"
        except Exception:
            pass
    return "anthropic/claude-sonnet-4-20250514"


@dataclass
class RuntimeConfig:
    model: str = field(default_factory=_load_preferred_model)
    temperature: float = 0.7
    max_tokens: int = 8000
    api_key: str | None = None
    api_base: str | None = None


default_config = RuntimeConfig()


@dataclass
class AgentMetadata:
    name: str = "Master Agent"
    version: str = "1.0.0"
    description: str = (
        "Education-specific automation agent that builds production-ready TeamAgents "
        "agent packages from natural language specifications. Dedicated to automating "
        "tasks for students, teachers, and school/college management."
    )
    intro_message: str = (
        "I'm the Master Agent — your Education Automation Architect. Describe the workflow "
        "you want to automate for your classroom, studies, or school management, and I'll "
        "design, implement, and validate a custom agent for you."
    )


metadata = AgentMetadata()

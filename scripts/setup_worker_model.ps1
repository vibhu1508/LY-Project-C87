#Requires -Version 5.1
<#
.SYNOPSIS
    setup_worker_model.ps1 - Configure a separate LLM model for worker agents

.DESCRIPTION
    Worker agents can use a different (e.g. cheaper/faster) model than the
    queen agent.  This script writes a "worker_llm" section to
    ~/.teamagents/configuration.json.  If no worker model is configured, workers
    fall back to the default (queen) model.

.NOTES
    Run from the project root: .\scripts\setup_worker_model.ps1
#>

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectDir = Split-Path -Parent $ScriptDir
$UvHelperPath = Join-Path $ScriptDir "uv-discovery.ps1"
$TeamAgentsConfigDir = Join-Path $env:USERPROFILE ".teamagents"
$TeamAgentsConfigFile = Join-Path $TeamAgentsConfigDir "configuration.json"
$TeamAgentsLlmEndpoint = "https://api.adenhq.com"

. $UvHelperPath

# ============================================================
# Colors / helpers
# ============================================================

function Write-Color {
    param(
        [string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::White,
        [switch]$NoNewline
    )
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    if ($NoNewline) { Write-Host $Text -NoNewline }
    else { Write-Host $Text }
    $Host.UI.RawUI.ForegroundColor = $prev
}

function Write-Ok {
    param([string]$Text)
    Write-Color -Text "$([char]0x2B22) $Text" -Color Green
}

function Write-Warn {
    param([string]$Text)
    Write-Color -Text "$([char]0x2B22) $Text" -Color Yellow
}

function Write-Fail {
    param([string]$Text)
    Write-Color -Text "  X $Text" -Color Red
}

# ============================================================
# Provider / model data
# ============================================================

$ProviderMap = [ordered]@{
    ANTHROPIC_API_KEY = @{ Name = "Anthropic (Claude)"; Id = "anthropic" }
    OPENAI_API_KEY    = @{ Name = "OpenAI (GPT)";       Id = "openai" }
    GEMINI_API_KEY    = @{ Name = "Google Gemini";       Id = "gemini" }
    GOOGLE_API_KEY    = @{ Name = "Google AI";           Id = "google" }
    GROQ_API_KEY      = @{ Name = "Groq";               Id = "groq" }
    CEREBRAS_API_KEY  = @{ Name = "Cerebras";            Id = "cerebras" }
    OPENROUTER_API_KEY = @{ Name = "OpenRouter";          Id = "openrouter" }
    MISTRAL_API_KEY   = @{ Name = "Mistral";             Id = "mistral" }
    TOGETHER_API_KEY  = @{ Name = "Together AI";         Id = "together" }
    DEEPSEEK_API_KEY  = @{ Name = "DeepSeek";            Id = "deepseek" }
}

$DefaultModels = @{
    anthropic   = "claude-haiku-4-5-20251001"
    openai      = "gpt-5-mini"
    gemini      = "gemini-3-flash-preview"
    groq        = "moonshotai/kimi-k2-instruct-0905"
    cerebras    = "zai-glm-4.7"
    mistral     = "mistral-large-latest"
    together_ai = "meta-llama/Llama-3.3-70B-Instruct-Turbo"
    deepseek    = "deepseek-chat"
}

# Model choices: array of hashtables per provider
$ModelChoices = @{
    anthropic = @(
        @{ Id = "claude-haiku-4-5-20251001";  Label = "Haiku 4.5 - Fast + cheap (recommended)"; MaxTokens = 8192;  MaxContextTokens = 180000 },
        @{ Id = "claude-sonnet-4-20250514";   Label = "Sonnet 4 - Fast + capable";              MaxTokens = 8192;  MaxContextTokens = 180000 },
        @{ Id = "claude-sonnet-4-5-20250929"; Label = "Sonnet 4.5 - Best balance";              MaxTokens = 16384; MaxContextTokens = 180000 },
        @{ Id = "claude-opus-4-6";            Label = "Opus 4.6 - Most capable";                MaxTokens = 32768; MaxContextTokens = 180000 }
    )
    openai = @(
        @{ Id = "gpt-5-mini"; Label = "GPT-5 Mini - Fast + cheap (recommended)"; MaxTokens = 16384; MaxContextTokens = 120000 },
        @{ Id = "gpt-5.2";   Label = "GPT-5.2 - Most capable";                   MaxTokens = 16384; MaxContextTokens = 120000 }
    )
    gemini = @(
        @{ Id = "gemini-3-flash-preview"; Label = "Gemini 3 Flash - Fast (recommended)"; MaxTokens = 8192; MaxContextTokens = 900000 },
        @{ Id = "gemini-3.1-pro-preview";  Label = "Gemini 3.1 Pro - Best quality";       MaxTokens = 8192; MaxContextTokens = 900000 }
    )
    groq = @(
        @{ Id = "moonshotai/kimi-k2-instruct-0905"; Label = "Kimi K2 - Best quality (recommended)"; MaxTokens = 8192; MaxContextTokens = 120000 },
        @{ Id = "openai/gpt-oss-120b";              Label = "GPT-OSS 120B - Fast reasoning";        MaxTokens = 8192; MaxContextTokens = 120000 }
    )
    cerebras = @(
        @{ Id = "zai-glm-4.7";                    Label = "ZAI-GLM 4.7 - Best quality (recommended)"; MaxTokens = 8192; MaxContextTokens = 120000 },
        @{ Id = "qwen3-235b-a22b-instruct-2507";  Label = "Qwen3 235B - Frontier reasoning";          MaxTokens = 8192; MaxContextTokens = 120000 }
    )
}

function Normalize-OpenRouterModelId {
    param([string]$ModelId)
    $normalized = if ($ModelId) { $ModelId.Trim() } else { "" }
    if ($normalized -match '(?i)^openrouter/(.+)$') {
        $normalized = $matches[1]
    }
    return $normalized
}

function Get-ModelSelection {
    param([string]$ProviderId)

    if ($ProviderId -eq "openrouter") {
        $defaultModel = ""
        if ($PrevModel -and $PrevProvider -eq $ProviderId) {
            $defaultModel = Normalize-OpenRouterModelId $PrevModel
        }
        Write-Host ""
        Write-Color -Text "Enter your OpenRouter model id:" -Color White
        Write-Color -Text "  Paste from openrouter.ai (example: x-ai/grok-4.20-beta)" -Color DarkGray
        Write-Color -Text "  If calls fail with guardrail/privacy errors: openrouter.ai/settings/privacy" -Color DarkGray
        Write-Host ""
        while ($true) {
            if ($defaultModel) {
                $rawModel = Read-Host "Model id [$defaultModel]"
                if ([string]::IsNullOrWhiteSpace($rawModel)) { $rawModel = $defaultModel }
            } else {
                $rawModel = Read-Host "Model id"
            }
            $normalizedModel = Normalize-OpenRouterModelId $rawModel
            if (-not [string]::IsNullOrWhiteSpace($normalizedModel)) {
                $openrouterKey = $null
                if ($SelectedEnvVar) {
                    $openrouterKey = [System.Environment]::GetEnvironmentVariable($SelectedEnvVar, "Process")
                    if (-not $openrouterKey) {
                        $openrouterKey = [System.Environment]::GetEnvironmentVariable($SelectedEnvVar, "User")
                    }
                }

                if ($openrouterKey) {
                    Write-Host "  Verifying model id... " -NoNewline
                    try {
                        $modelApiBase = if ($SelectedApiBase) { $SelectedApiBase } else { "https://openrouter.ai/api/v1" }
                        Push-Location $ProjectDir
                        $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") "openrouter" $openrouterKey $modelApiBase $normalizedModel 2>$null
                        Pop-Location
                        $hcJson = $hcResult | ConvertFrom-Json
                        if ($hcJson.valid -eq $true) {
                            if ($hcJson.model) {
                                $normalizedModel = [string]$hcJson.model
                            }
                            Write-Color -Text "ok" -Color Green
                        } elseif ($hcJson.valid -eq $false) {
                            Write-Color -Text "failed" -Color Red
                            Write-Warn $hcJson.message
                            Write-Host ""
                            continue
                        } else {
                            Write-Color -Text "--" -Color Yellow
                            Write-Color -Text "  Could not verify model id (network issue). Continuing with your selection." -Color DarkGray
                        }
                    } catch {
                        Pop-Location
                        Write-Color -Text "--" -Color Yellow
                        Write-Color -Text "  Could not verify model id (network issue). Continuing with your selection." -Color DarkGray
                    }
                } else {
                    Write-Color -Text "  Skipping model verification (OpenRouter key not available in current shell)." -Color DarkGray
                }

                Write-Host ""
                Write-Ok "Model: $normalizedModel"
                return @{ Model = $normalizedModel; MaxTokens = 8192; MaxContextTokens = 120000 }
            }
            Write-Color -Text "Model id cannot be empty." -Color Red
        }
    }

    $choices = $ModelChoices[$ProviderId]
    if (-not $choices -or $choices.Count -eq 0) {
        return @{ Model = $DefaultModels[$ProviderId]; MaxTokens = 8192; MaxContextTokens = 120000 }
    }
    if ($choices.Count -eq 1) {
        return @{ Model = $choices[0].Id; MaxTokens = $choices[0].MaxTokens; MaxContextTokens = $choices[0].MaxContextTokens }
    }

    # Find default index from previous model (if same provider)
    $defaultIdx = "1"
    if ($PrevModel -and $PrevProvider -eq $ProviderId) {
        for ($j = 0; $j -lt $choices.Count; $j++) {
            if ($choices[$j].Id -eq $PrevModel) {
                $defaultIdx = [string]($j + 1)
                break
            }
        }
    }

    Write-Host ""
    Write-Color -Text "Select a model:" -Color White
    Write-Host ""
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-Color -Text "  $($i + 1)" -Color Cyan -NoNewline
        Write-Host ") $($choices[$i].Label)  " -NoNewline
        Write-Color -Text "($($choices[$i].Id))" -Color DarkGray
    }
    Write-Host ""

    while ($true) {
        $raw = Read-Host "Enter choice [$defaultIdx]"
        if ([string]::IsNullOrWhiteSpace($raw)) { $raw = $defaultIdx }
        if ($raw -match '^\d+$') {
            $num = [int]$raw
            if ($num -ge 1 -and $num -le $choices.Count) {
                $sel = $choices[$num - 1]
                Write-Host ""
                Write-Ok "Model: $($sel.Id)"
                return @{ Model = $sel.Id; MaxTokens = $sel.MaxTokens; MaxContextTokens = $sel.MaxContextTokens }
            }
        }
        Write-Color -Text "Invalid choice. Please enter 1-$($choices.Count)" -Color Red
    }
}

# ============================================================
# Main
# ============================================================

$uvInfo = Get-WorkingUvInfo
if (-not $uvInfo) {
    Write-Color -Text "uv is not installed or is not runnable. Run .\quickstart.ps1 first." -Color Red
    exit 1
}
$UvCmd = $uvInfo.Path

Write-Host ""
Write-Color -Text "$([char]0x2B22) Worker Model Setup" -Color Yellow
Write-Host ""
Write-Color -Text "Configure a separate LLM model for worker agents." -Color DarkGray
Write-Color -Text "Worker agents will use this model instead of the default queen model." -Color DarkGray
Write-Host ""

# Show current configuration
if (Test-Path $TeamAgentsConfigFile) {
    try {
        Push-Location $ProjectDir
        $currentConfig = & $UvCmd run python -c "
from framework.config import get_preferred_model, get_preferred_worker_model
print(f'Queen:  {get_preferred_model()}')
wm = get_preferred_worker_model()
print(f'Worker: {wm if wm else chr(34) + ""(same as queen)"" + chr(34)}')
" 2>$null
        Pop-Location
        if ($currentConfig) {
            Write-Color -Text "Current configuration:" -Color White
            foreach ($line in $currentConfig) {
                Write-Color -Text "  $line" -Color DarkGray
            }
            Write-Host ""
        }
    } catch {
        Pop-Location
    }
}

# ============================================================
# Configure Worker LLM Provider
# ============================================================

$SelectedProviderId      = ""
$SelectedEnvVar          = ""
$SelectedModel           = ""
$SelectedMaxTokens       = 8192
$SelectedMaxContextTokens = 120000
$SelectedApiBase         = ""
$SubscriptionMode        = ""

# -- Credential detection (silent -- just set flags) ----------
$ClaudeCredDetected = $false
$claudeCredPath = Join-Path $env:USERPROFILE ".claude\.credentials.json"
if (Test-Path $claudeCredPath) { $ClaudeCredDetected = $true }

$CodexCredDetected = $false
$codexAuthPath = Join-Path $env:USERPROFILE ".codex\auth.json"
if (Test-Path $codexAuthPath) { $CodexCredDetected = $true }

$ZaiCredDetected = $false
$zaiKey = [System.Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
if (-not $zaiKey) { $zaiKey = $env:ZAI_API_KEY }
if ($zaiKey) { $ZaiCredDetected = $true }

$MinimaxCredDetected = $false
$minimaxKey = [System.Environment]::GetEnvironmentVariable("MINIMAX_API_KEY", "User")
if (-not $minimaxKey) { $minimaxKey = $env:MINIMAX_API_KEY }
if ($minimaxKey) { $MinimaxCredDetected = $true }

$KimiCredDetected = $false
$kimiConfigPath = Join-Path $env:USERPROFILE ".kimi\config.toml"
if (Test-Path $kimiConfigPath) { $KimiCredDetected = $true }
$kimiKey = [System.Environment]::GetEnvironmentVariable("KIMI_API_KEY", "User")
if (-not $kimiKey) { $kimiKey = $env:KIMI_API_KEY }
if ($kimiKey) { $KimiCredDetected = $true }

$TeamAgentsCredDetected = $false
$teamAgentsKey = [System.Environment]::GetEnvironmentVariable("HIVE_API_KEY", "User")
if (-not $teamAgentsKey) { $teamAgentsKey = $env:HIVE_API_KEY }
if ($teamAgentsKey) { $TeamAgentsCredDetected = $true }

$AntigravityCredDetected = $false
# Check native Antigravity IDE (Windows) SQLite state DB
$antigravityVscdbPath = Join-Path $env:APPDATA "Antigravity\User\globalStorage\state.vscdb"
if (Test-Path $antigravityVscdbPath) { $AntigravityCredDetected = $true }
# Native OAuth credentials
$antigravityAccountsPath = Join-Path $env:USERPROFILE ".teamagents\antigravity-accounts.json"
if (Test-Path $antigravityAccountsPath) { $AntigravityCredDetected = $true }

# Detect API key providers
$ProviderMenuEnvVars  = @("ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GROQ_API_KEY", "CEREBRAS_API_KEY", "OPENROUTER_API_KEY")
$ProviderMenuNames    = @("Anthropic (Claude) - Recommended", "OpenAI (GPT)", "Google Gemini - Free tier available", "Groq - Fast, free tier", "Cerebras - Fast, free tier", "OpenRouter - Bring any OpenRouter model")
$ProviderMenuIds      = @("anthropic", "openai", "gemini", "groq", "cerebras", "openrouter")
$ProviderMenuUrls     = @(
    "https://console.anthropic.com/settings/keys",
    "https://platform.openai.com/api-keys",
    "https://aistudio.google.com/apikey",
    "https://console.groq.com/keys",
    "https://cloud.cerebras.ai/",
    "https://openrouter.ai/keys"
)

# -- Read previous worker_llm configuration (if any) ---------
$PrevProvider = ""
$PrevModel = ""
$PrevEnvVar = ""
$PrevSubMode = ""
if (Test-Path $TeamAgentsConfigFile) {
    try {
        $prevConfig = Get-Content -Path $TeamAgentsConfigFile -Raw | ConvertFrom-Json
        $prevLlm = $prevConfig.worker_llm
        if ($prevLlm) {
            $PrevProvider = if ($prevLlm.provider) { $prevLlm.provider } else { "" }
            $PrevModel = if ($prevLlm.model) { $prevLlm.model } else { "" }
            $PrevEnvVar = if ($prevLlm.api_key_env_var) { $prevLlm.api_key_env_var } else { "" }
            if ($prevLlm.use_claude_code_subscription) { $PrevSubMode = "claude_code" }
            elseif ($prevLlm.use_codex_subscription) { $PrevSubMode = "codex" }
            elseif ($prevLlm.use_antigravity_subscription) { $PrevSubMode = "antigravity" }
            elseif ($prevLlm.use_kimi_code_subscription) { $PrevSubMode = "kimi_code" }
            elseif ($prevLlm.provider -eq "minimax" -or ($prevLlm.api_base -and $prevLlm.api_base -like "*api.minimax.io*")) { $PrevSubMode = "minimax_code" }
            elseif ($prevLlm.api_base -and $prevLlm.api_base -like "*api.z.ai*") { $PrevSubMode = "zai_code" }
            elseif ($prevLlm.api_base -and $prevLlm.api_base -like "*api.kimi.com*") { $PrevSubMode = "kimi_code" }
            elseif ($prevLlm.provider -eq "teamagents" -or ($prevLlm.api_base -and $prevLlm.api_base -like "*adenhq.com*")) { $PrevSubMode = "teamagents_llm" }
        }
    } catch { }
}

# Compute default menu number (only if credential is still valid)
$DefaultChoice = ""
if ($PrevSubMode -or $PrevProvider) {
    $prevCredValid = $false
    switch ($PrevSubMode) {
        "claude_code"   { if ($ClaudeCredDetected)      { $prevCredValid = $true } }
        "zai_code"      { if ($ZaiCredDetected)         { $prevCredValid = $true } }
        "codex"         { if ($CodexCredDetected)       { $prevCredValid = $true } }
        "minimax_code"  { if ($MinimaxCredDetected)     { $prevCredValid = $true } }
        "kimi_code"     { if ($KimiCredDetected)        { $prevCredValid = $true } }
        "teamagents_llm"      { if ($TeamAgentsCredDetected)        { $prevCredValid = $true } }
        "antigravity"   { if ($AntigravityCredDetected) { $prevCredValid = $true } }
        default {
            if ($PrevEnvVar) {
                $envVal = [System.Environment]::GetEnvironmentVariable($PrevEnvVar, "Process")
                if (-not $envVal) { $envVal = [System.Environment]::GetEnvironmentVariable($PrevEnvVar, "User") }
                if ($envVal) { $prevCredValid = $true }
            }
        }
    }
    if ($prevCredValid) {
        switch ($PrevSubMode) {
            "claude_code"   { $DefaultChoice = "1" }
            "zai_code"      { $DefaultChoice = "2" }
            "codex"         { $DefaultChoice = "3" }
            "minimax_code"  { $DefaultChoice = "4" }
            "kimi_code"     { $DefaultChoice = "5" }
            "teamagents_llm"      { $DefaultChoice = "6" }
            "antigravity"   { $DefaultChoice = "7" }
        }
        if (-not $DefaultChoice) {
            switch ($PrevProvider) {
                "anthropic"  { $DefaultChoice = "8" }
                "openai"     { $DefaultChoice = "9" }
                "gemini"     { $DefaultChoice = "10" }
                "groq"       { $DefaultChoice = "11" }
                "cerebras"   { $DefaultChoice = "12" }
                "openrouter" { $DefaultChoice = "13" }
                "minimax"    { $DefaultChoice = "4" }
                "kimi"       { $DefaultChoice = "5" }
                "teamagents"       { $DefaultChoice = "6" }
            }
        }
    }
}

# Enforce allowlist in menu defaults (Gemini, Groq, OpenRouter only)
$AllowedDefaultChoices = @{
    "gemini" = "1"
    "groq" = "2"
    "openrouter" = "3"
}
if ($PrevProvider -and $AllowedDefaultChoices.ContainsKey($PrevProvider)) {
    $DefaultChoice = $AllowedDefaultChoices[$PrevProvider]
} else {
    $DefaultChoice = ""
}

# -- Show unified provider selection menu ---------------------
Write-Color -Text "Select your worker LLM provider:" -Color White
Write-Host ""
Write-Color -Text "  Allowed API key providers:" -Color Cyan

$AllowedProviders = @(
    @{ Label = "Google Gemini"; MenuNum = 1; InternalNum = 10; Env = "GEMINI_API_KEY" },
    @{ Label = "Groq"; MenuNum = 2; InternalNum = 11; Env = "GROQ_API_KEY" },
    @{ Label = "OpenRouter"; MenuNum = 3; InternalNum = 13; Env = "OPENROUTER_API_KEY" }
)
foreach ($item in $AllowedProviders) {
    $envVal = [System.Environment]::GetEnvironmentVariable($item.Env, "Process")
    if (-not $envVal) { $envVal = [System.Environment]::GetEnvironmentVariable($item.Env, "User") }
    Write-Host "  " -NoNewline
    Write-Color -Text "$($item.MenuNum)" -Color Cyan -NoNewline
    Write-Host ") $($item.Label)" -NoNewline
    if ($envVal) { Write-Color -Text "  (credential detected)" -Color Green } else { Write-Host "" }
}

$SkipChoice = 4
Write-Host "  " -NoNewline
Write-Color -Text "$SkipChoice" -Color Cyan -NoNewline
Write-Host ") Skip for now"
Write-Host ""

if ($DefaultChoice) {
    Write-Color -Text "  Previously configured: $PrevProvider/$PrevModel. Press Enter to keep." -Color DarkGray
    Write-Host ""
}

while ($true) {
    if ($DefaultChoice) {
        $raw = Read-Host "Enter choice (1-$SkipChoice) [$DefaultChoice]"
        if ([string]::IsNullOrWhiteSpace($raw)) { $raw = $DefaultChoice }
    } else {
        $raw = Read-Host "Enter choice (1-$SkipChoice)"
    }
    if ($raw -match '^\d+$') {
        $num = [int]$raw
        if ($num -ge 1 -and $num -le $SkipChoice) { break }
    }
    Write-Color -Text "Invalid choice. Please enter 1-$SkipChoice" -Color Red
}

# Map allowlist menu choices to existing internal switch numbers.
if ($num -eq 1) {
    $num = 10  # Gemini
} elseif ($num -eq 2) {
    $num = 11  # Groq
} elseif ($num -eq 3) {
    $num = 13  # OpenRouter
}
$SkipChoiceInternal = 199
if ($num -eq $SkipChoice) {
    $num = $SkipChoiceInternal
}

switch ($num) {
    1 {
        # Claude Code Subscription
        if (-not $ClaudeCredDetected) {
            Write-Host ""
            Write-Warn "~/.claude/.credentials.json not found."
            Write-Host "  Run 'claude' first to authenticate with your Claude subscription,"
            Write-Host "  then run this script again."
            Write-Host ""
            exit 1
        }
        $SubscriptionMode        = "claude_code"
        $SelectedProviderId      = "anthropic"
        $SelectedModel           = "claude-opus-4-6"
        $SelectedMaxTokens       = 32768
        $SelectedMaxContextTokens = 180000
        Write-Host ""
        Write-Ok "Using Claude Code subscription"
    }
    2 {
        # ZAI Code Subscription
        $SubscriptionMode        = "zai_code"
        $SelectedProviderId      = "openai"
        $SelectedEnvVar          = "ZAI_API_KEY"
        $SelectedModel           = "glm-5"
        $SelectedMaxTokens       = 32768
        $SelectedMaxContextTokens = 120000
        Write-Host ""
        Write-Ok "Using ZAI Code subscription"
        Write-Color -Text "  Model: glm-5 | API: api.z.ai" -Color DarkGray
    }
    3 {
        # OpenAI Codex Subscription
        if (-not $CodexCredDetected) {
            Write-Host ""
            Write-Warn "Codex credentials not found. Starting OAuth login..."
            Write-Host ""
            try {
                Push-Location $ProjectDir
                & $UvCmd run python (Join-Path $ProjectDir "core\codex_oauth.py") 2>&1
                Pop-Location
                if ($LASTEXITCODE -eq 0) {
                    $CodexCredDetected = $true
                } else {
                    Write-Host ""
                    Write-Fail "OAuth login failed or was cancelled."
                    Write-Host ""
                    Write-Host "  Or run 'codex' to authenticate, then run this script again."
                    Write-Host ""
                    $SelectedProviderId = ""
                }
            } catch {
                Pop-Location
                Write-Fail "OAuth login failed: $($_.Exception.Message)"
                $SelectedProviderId = ""
            }
        }
        if ($CodexCredDetected) {
            $SubscriptionMode        = "codex"
            $SelectedProviderId      = "openai"
            $SelectedModel           = "gpt-5.3-codex"
            $SelectedMaxTokens       = 16384
            $SelectedMaxContextTokens = 120000
            Write-Host ""
            Write-Ok "Using OpenAI Codex subscription"
        }
    }
    4 {
        # MiniMax Coding Key
        $SubscriptionMode        = "minimax_code"
        $SelectedEnvVar          = "MINIMAX_API_KEY"
        $SelectedProviderId      = "minimax"
        $SelectedModel           = "MiniMax-M2.5"
        $SelectedMaxTokens       = 32768
        $SelectedMaxContextTokens = 900000  # MiniMax M2.5 â€” 1M context window
        $SelectedApiBase         = "https://api.minimax.io/v1"
        Write-Host ""
        Write-Ok "Using MiniMax coding key"
        Write-Color -Text "  Model: MiniMax-M2.5 | API: api.minimax.io" -Color DarkGray
    }
    5 {
        # Kimi Code Subscription
        $SubscriptionMode        = "kimi_code"
        $SelectedProviderId      = "kimi"
        $SelectedEnvVar          = "KIMI_API_KEY"
        $SelectedModel           = "kimi-k2.5"
        $SelectedMaxTokens       = 32768
        $SelectedMaxContextTokens = 120000
        Write-Host ""
        Write-Ok "Using Kimi Code subscription"
        Write-Color -Text "  Model: kimi-k2.5 | API: api.kimi.com/coding" -Color DarkGray
    }
    6 {
        # TeamAgents LLM
        $SubscriptionMode        = "teamagents_llm"
        $SelectedProviderId      = "teamagents"
        $SelectedEnvVar          = "HIVE_API_KEY"
        $SelectedMaxTokens       = 32768
        $SelectedMaxContextTokens = 120000
        Write-Host ""
        Write-Ok "Using TeamAgents LLM"
        Write-Host ""
        Write-Host "  Select a model:"
        Write-Host "  " -NoNewline; Write-Color -Text "1)" -Color Cyan -NoNewline; Write-Host " queen              " -NoNewline; Write-Color -Text "(default - TeamAgents flagship)" -Color DarkGray
        Write-Host "  " -NoNewline; Write-Color -Text "2)" -Color Cyan -NoNewline; Write-Host " kimi-2.5"
        Write-Host "  " -NoNewline; Write-Color -Text "3)" -Color Cyan -NoNewline; Write-Host " GLM-5"
        Write-Host ""
        $teamAgentsModelChoice = Read-Host "  Enter model choice (1-3) [1]"
        if (-not $teamAgentsModelChoice) { $teamAgentsModelChoice = "1" }
        switch ($teamAgentsModelChoice) {
            "2" { $SelectedModel = "kimi-2.5" }
            "3" { $SelectedModel = "GLM-5" }
            default { $SelectedModel = "queen" }
        }
        Write-Color -Text "  Model: $SelectedModel | API: $TeamAgentsLlmEndpoint" -Color DarkGray
    }
    7 {
        # Antigravity Subscription
        if (-not $AntigravityCredDetected) {
            Write-Host ""
            Write-Color -Text "  Setting up Antigravity authentication..." -Color Cyan
            Write-Host ""
            Write-Color -Text "  A browser window will open for Google OAuth." -Color Yellow
            Write-Host "  Sign in with your Google account that has Antigravity access."
            Write-Host ""

            # Run native OAuth flow
            try {
                Push-Location $ProjectDir
                & $UvCmd run python (Join-Path $ProjectDir "core\antigravity_auth.py") auth account add 2>&1
                Pop-Location
                # Re-detect credentials
                $antigravityAccountsPath = Join-Path $env:USERPROFILE ".teamagents\antigravity-accounts.json"
                if (Test-Path $antigravityAccountsPath) {
                    $AntigravityCredDetected = $true
                }
            } catch {
                Pop-Location
            }

            if (-not $AntigravityCredDetected) {
                Write-Host ""
                Write-Fail "Authentication failed or was cancelled."
                Write-Host ""
                exit 1
            }
        }

        if ($AntigravityCredDetected) {
            $SubscriptionMode         = "antigravity"
            $SelectedProviderId       = "openai"
            $SelectedModel            = "gemini-3-flash"
            $SelectedMaxTokens        = 32768
            $SelectedMaxContextTokens = 1000000  # Gemini 3 Flash â€” 1M context window
            Write-Host ""
            Write-Warn "Using Antigravity can technically cause your account suspension. Please use at your own risk."
            Write-Host ""
            Write-Ok "Using Antigravity subscription"
            Write-Color -Text "  Model: gemini-3-flash | Direct OAuth (no proxy required)" -Color DarkGray
        }
    }
    { $_ -ge 8 -and $_ -le 13 } {
        # API key providers
        $provIdx = $num - 8
        $SelectedEnvVar     = $ProviderMenuEnvVars[$provIdx]
        $SelectedProviderId = $ProviderMenuIds[$provIdx]
        $providerName       = $ProviderMenuNames[$provIdx] -replace ' - .*', ''  # strip description
        $signupUrl          = $ProviderMenuUrls[$provIdx]
        if ($SelectedProviderId -eq "openrouter") {
            $SelectedApiBase = "https://openrouter.ai/api/v1"
        } else {
            $SelectedApiBase = ""
        }

        # Prompt for key (allow replacement if already set) with verification + retry
        while ($true) {
            $existingKey = [System.Environment]::GetEnvironmentVariable($SelectedEnvVar, "User")
            if (-not $existingKey) { $existingKey = [System.Environment]::GetEnvironmentVariable($SelectedEnvVar, "Process") }

            if ($existingKey) {
                $masked = $existingKey.Substring(0, [Math]::Min(4, $existingKey.Length)) + "..." + $existingKey.Substring([Math]::Max(0, $existingKey.Length - 4))
                Write-Host ""
                Write-Color -Text "  $([char]0x2B22) Current key: $masked" -Color Green
                $apiKey = Read-Host "  Press Enter to keep, or paste a new key to replace"
            } else {
                Write-Host ""
                Write-Host "Get your API key from: " -NoNewline
                Write-Color -Text $signupUrl -Color Cyan
                Write-Host ""
                $apiKey = Read-Host "Paste your $providerName API key (or press Enter to skip)"
            }

            if ($apiKey) {
                [System.Environment]::SetEnvironmentVariable($SelectedEnvVar, $apiKey, "User")
                Set-Item -Path "Env:\$SelectedEnvVar" -Value $apiKey
                Write-Host ""
                Write-Ok "API key saved as User environment variable: $SelectedEnvVar"

                # Health check the new key
                Write-Host "  Verifying API key... " -NoNewline
                try {
                    Push-Location $ProjectDir
                    if ($SelectedApiBase) {
                        $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") $SelectedProviderId $apiKey $SelectedApiBase 2>$null
                    } else {
                        $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") $SelectedProviderId $apiKey 2>$null
                    }
                    Pop-Location
                    $hcJson = $hcResult | ConvertFrom-Json
                    if ($hcJson.valid -eq $true) {
                        Write-Color -Text "ok" -Color Green
                        break
                    } elseif ($hcJson.valid -eq $false) {
                        Write-Color -Text "failed" -Color Red
                        Write-Warn $hcJson.message
                        # Undo the save so user can retry cleanly
                        [System.Environment]::SetEnvironmentVariable($SelectedEnvVar, $null, "User")
                        Remove-Item -Path "Env:\$SelectedEnvVar" -ErrorAction SilentlyContinue
                        Write-Host ""
                        Read-Host "  Press Enter to try again"
                        # loop back to key prompt
                    } else {
                        Write-Color -Text "--" -Color Yellow
                        Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                        break
                    }
                } catch {
                    Pop-Location
                    Write-Color -Text "--" -Color Yellow
                    Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                    break
                }
            } elseif (-not $existingKey) {
                # No existing key and user skipped
                Write-Host ""
                Write-Warn "Skipped. Set the environment variable manually when ready:"
                Write-Host "  [System.Environment]::SetEnvironmentVariable('$SelectedEnvVar', 'your-key', 'User')"
                $SelectedEnvVar     = ""
                $SelectedProviderId = ""
                break
            } else {
                # User pressed Enter with existing key -- keep it
                break
            }
        }
    }
    { $_ -eq $SkipChoiceInternal } {
        Write-Host ""
        Write-Warn "Skipped. A worker LLM provider is required for worker agents."
        Write-Host "  Run this script again when ready."
        Write-Host ""
        $SelectedEnvVar     = ""
        $SelectedProviderId = ""
    }
}

# For ZAI subscription: prompt for API key (allow replacement if already set) with verification + retry
if ($SubscriptionMode -eq "zai_code") {
    while ($true) {
        $existingZai = [System.Environment]::GetEnvironmentVariable("ZAI_API_KEY", "User")
        if (-not $existingZai) { $existingZai = $env:ZAI_API_KEY }

        if ($existingZai) {
            $masked = $existingZai.Substring(0, [Math]::Min(4, $existingZai.Length)) + "..." + $existingZai.Substring([Math]::Max(0, $existingZai.Length - 4))
            Write-Host ""
            Write-Color -Text "  $([char]0x2B22) Current ZAI key: $masked" -Color Green
            $apiKey = Read-Host "  Press Enter to keep, or paste a new key to replace"
        } else {
            Write-Host ""
            $apiKey = Read-Host "Paste your ZAI API key (or press Enter to skip)"
        }

        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("ZAI_API_KEY", $apiKey, "User")
            $env:ZAI_API_KEY = $apiKey
            Write-Host ""
            Write-Ok "ZAI API key saved as User environment variable"

            # Health check the new key
            Write-Host "  Verifying ZAI API key... " -NoNewline
            try {
                Push-Location $ProjectDir
                $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") "zai" $apiKey "https://api.z.ai/api/coding/paas/v4" 2>$null
                Pop-Location
                $hcJson = $hcResult | ConvertFrom-Json
                if ($hcJson.valid -eq $true) {
                    Write-Color -Text "ok" -Color Green
                    break
                } elseif ($hcJson.valid -eq $false) {
                    Write-Color -Text "failed" -Color Red
                    Write-Warn $hcJson.message
                    # Undo the save so user can retry cleanly
                    [System.Environment]::SetEnvironmentVariable("ZAI_API_KEY", $null, "User")
                    Remove-Item -Path "Env:\ZAI_API_KEY" -ErrorAction SilentlyContinue
                    Write-Host ""
                    Read-Host "  Press Enter to try again"
                    # loop back to key prompt
                } else {
                    Write-Color -Text "--" -Color Yellow
                    Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                    break
                }
            } catch {
                Pop-Location
                Write-Color -Text "--" -Color Yellow
                Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                break
            }
        } elseif (-not $existingZai) {
            # No existing key and user skipped
            Write-Host ""
            Write-Warn "Skipped. Add your ZAI API key later:"
            Write-Color -Text "  [System.Environment]::SetEnvironmentVariable('ZAI_API_KEY', 'your-key', 'User')" -Color Cyan
            $SelectedEnvVar     = ""
            $SelectedProviderId = ""
            $SubscriptionMode   = ""
            break
        } else {
            # User pressed Enter with existing key -- keep it
            break
        }
    }
}

# For MiniMax coding key: prompt for API key with verification + retry
if ($SubscriptionMode -eq "minimax_code") {
    while ($true) {
        $existingMinimax = [System.Environment]::GetEnvironmentVariable("MINIMAX_API_KEY", "User")
        if (-not $existingMinimax) { $existingMinimax = $env:MINIMAX_API_KEY }

        if ($existingMinimax) {
            $masked = $existingMinimax.Substring(0, [Math]::Min(4, $existingMinimax.Length)) + "..." + $existingMinimax.Substring([Math]::Max(0, $existingMinimax.Length - 4))
            Write-Host ""
            Write-Color -Text "  $([char]0x2B22) Current MiniMax key: $masked" -Color Green
            $apiKey = Read-Host "  Press Enter to keep, or paste a new key to replace"
        } else {
            Write-Host ""
            Write-Host "Get your API key from: " -NoNewline
            Write-Color -Text "https://platform.minimax.io/user-center/basic-information/interface-key" -Color Cyan
            Write-Host ""
            $apiKey = Read-Host "Paste your MiniMax API key (or press Enter to skip)"
        }

        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("MINIMAX_API_KEY", $apiKey, "User")
            $env:MINIMAX_API_KEY = $apiKey
            Write-Host ""
            Write-Ok "MiniMax API key saved as User environment variable"

            # Health check the new key
            Write-Host "  Verifying MiniMax API key... " -NoNewline
            try {
                Push-Location $ProjectDir
                $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") "minimax" $apiKey "https://api.minimax.io/v1" 2>$null
                Pop-Location
                $hcJson = $hcResult | ConvertFrom-Json
                if ($hcJson.valid -eq $true) {
                    Write-Color -Text "ok" -Color Green
                    break
                } elseif ($hcJson.valid -eq $false) {
                    Write-Color -Text "failed" -Color Red
                    Write-Warn $hcJson.message
                    [System.Environment]::SetEnvironmentVariable("MINIMAX_API_KEY", $null, "User")
                    Remove-Item -Path "Env:\MINIMAX_API_KEY" -ErrorAction SilentlyContinue
                    Write-Host ""
                    Read-Host "  Press Enter to try again"
                } else {
                    Write-Color -Text "--" -Color Yellow
                    Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                    break
                }
            } catch {
                Pop-Location
                Write-Color -Text "--" -Color Yellow
                Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                break
            }
        } elseif (-not $existingMinimax) {
            Write-Host ""
            Write-Warn "Skipped. Add your MiniMax API key later:"
            Write-Color -Text "  [System.Environment]::SetEnvironmentVariable('MINIMAX_API_KEY', 'your-key', 'User')" -Color Cyan
            $SelectedEnvVar     = ""
            $SelectedProviderId = ""
            $SubscriptionMode   = ""
            break
        } else {
            break
        }
    }
}

# For Kimi Code subscription: prompt for API key with verification + retry
if ($SubscriptionMode -eq "kimi_code") {
    while ($true) {
        $existingKimi = [System.Environment]::GetEnvironmentVariable("KIMI_API_KEY", "User")
        if (-not $existingKimi) { $existingKimi = $env:KIMI_API_KEY }

        if ($existingKimi) {
            $masked = $existingKimi.Substring(0, [Math]::Min(4, $existingKimi.Length)) + "..." + $existingKimi.Substring([Math]::Max(0, $existingKimi.Length - 4))
            Write-Host ""
            Write-Color -Text "  $([char]0x2B22) Current Kimi key: $masked" -Color Green
            $apiKey = Read-Host "  Press Enter to keep, or paste a new key to replace"
        } else {
            Write-Host ""
            Write-Host "Get your API key from: " -NoNewline
            Write-Color -Text "https://www.kimi.com/code" -Color Cyan
            Write-Host ""
            $apiKey = Read-Host "Paste your Kimi API key (or press Enter to skip)"
        }

        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("KIMI_API_KEY", $apiKey, "User")
            $env:KIMI_API_KEY = $apiKey
            Write-Host ""
            Write-Ok "Kimi API key saved as User environment variable"

            # Health check the new key
            Write-Host "  Verifying Kimi API key... " -NoNewline
            try {
                Push-Location $ProjectDir
                $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") "kimi" $apiKey "https://api.kimi.com/coding" 2>$null
                Pop-Location
                $hcJson = $hcResult | ConvertFrom-Json
                if ($hcJson.valid -eq $true) {
                    Write-Color -Text "ok" -Color Green
                    break
                } elseif ($hcJson.valid -eq $false) {
                    Write-Color -Text "failed" -Color Red
                    Write-Warn $hcJson.message
                    [System.Environment]::SetEnvironmentVariable("KIMI_API_KEY", $null, "User")
                    Remove-Item -Path "Env:\KIMI_API_KEY" -ErrorAction SilentlyContinue
                    Write-Host ""
                    Read-Host "  Press Enter to try again"
                } else {
                    Write-Color -Text "--" -Color Yellow
                    Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                    break
                }
            } catch {
                Pop-Location
                Write-Color -Text "--" -Color Yellow
                Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                break
            }
        } elseif (-not $existingKimi) {
            Write-Host ""
            Write-Warn "Skipped. Add your Kimi API key later:"
            Write-Color -Text "  [System.Environment]::SetEnvironmentVariable('KIMI_API_KEY', 'your-key', 'User')" -Color Cyan
            $SelectedEnvVar     = ""
            $SelectedProviderId = ""
            $SubscriptionMode   = ""
            break
        } else {
            break
        }
    }
}

# For TeamAgents LLM: prompt for API key with verification + retry
if ($SubscriptionMode -eq "teamagents_llm") {
    while ($true) {
        $existingTeamAgents = [System.Environment]::GetEnvironmentVariable("HIVE_API_KEY", "User")
        if (-not $existingTeamAgents) { $existingTeamAgents = $env:HIVE_API_KEY }

        if ($existingTeamAgents) {
            $masked = $existingTeamAgents.Substring(0, [Math]::Min(4, $existingTeamAgents.Length)) + "..." + $existingTeamAgents.Substring([Math]::Max(0, $existingTeamAgents.Length - 4))
            Write-Host ""
            Write-Color -Text "  $([char]0x2B22) Current TeamAgents key: $masked" -Color Green
            Write-Host ""
            $apiKey = Read-Host "Paste a new TeamAgents API key (or press Enter to keep current)"
        } else {
            Write-Host ""
            Write-Host "  Get your API key from: " -NoNewline
            Write-Color -Text "https://discord.com/invite/hQdU7QDkgR" -Color Cyan
            Write-Host ""
            $apiKey = Read-Host "Paste your TeamAgents API key (or press Enter to skip)"
        }

        if ($apiKey) {
            [System.Environment]::SetEnvironmentVariable("HIVE_API_KEY", $apiKey, "User")
            $env:HIVE_API_KEY = $apiKey
            Write-Host ""
            Write-Ok "TeamAgents API key saved as User environment variable"

            # Health check the new key
            Write-Host "  Verifying TeamAgents API key... " -NoNewline
            try {
                Push-Location $ProjectDir
                $hcResult = & $UvCmd run python (Join-Path $ProjectDir "scripts/check_llm_key.py") "teamagents" $apiKey "$TeamAgentsLlmEndpoint" 2>$null
                Pop-Location
                $hcJson = $hcResult | ConvertFrom-Json
                if ($hcJson.valid -eq $true) {
                    Write-Color -Text "ok" -Color Green
                    break
                } elseif ($hcJson.valid -eq $false) {
                    Write-Color -Text "failed" -Color Red
                    Write-Warn $hcJson.message
                    [System.Environment]::SetEnvironmentVariable("HIVE_API_KEY", $null, "User")
                    Remove-Item -Path "Env:\HIVE_API_KEY" -ErrorAction SilentlyContinue
                    Write-Host ""
                    Read-Host "  Press Enter to try again"
                } else {
                    Write-Color -Text "--" -Color Yellow
                    Write-Color -Text "  Could not verify key (network issue). The key has been saved." -Color DarkGray
                    break
                }
            } catch {
                Pop-Location
                Write-Color -Text "--" -Color Yellow
                break
            }
        } elseif (-not $existingTeamAgents) {
            Write-Host ""
            Write-Warn "Skipped. Add your TeamAgents API key later:"
            Write-Color -Text "  [System.Environment]::SetEnvironmentVariable('HIVE_API_KEY', 'your-key', 'User')" -Color Cyan
            $SelectedEnvVar     = ""
            $SelectedProviderId = ""
            $SubscriptionMode   = ""
            break
        } else {
            break
        }
    }
}

# Prompt for model if not already selected (manual provider path)
if ($SelectedProviderId -and -not $SelectedModel) {
    $modelSel = Get-ModelSelection $SelectedProviderId
    $SelectedModel            = $modelSel.Model
    $SelectedMaxTokens        = $modelSel.MaxTokens
    $SelectedMaxContextTokens = $modelSel.MaxContextTokens
}

# ============================================================
# Save configuration to worker_llm section
# ============================================================

if ($SelectedProviderId) {
    if (-not $SelectedModel) {
        $SelectedModel = $DefaultModels[$SelectedProviderId]
    }
    Write-Host ""
    Write-Host "  Saving worker model configuration... " -NoNewline

    if (-not (Test-Path $TeamAgentsConfigDir)) {
        New-Item -ItemType Directory -Path $TeamAgentsConfigDir -Force | Out-Null
    }

    try {
        if (Test-Path $TeamAgentsConfigFile) {
            $config = Get-Content -Path $TeamAgentsConfigFile -Raw | ConvertFrom-Json
        } else {
            $config = @{}
        }
    } catch {
        $config = @{}
    }

    $workerLlm = @{
        provider           = $SelectedProviderId
        model              = $SelectedModel
        max_tokens         = $SelectedMaxTokens
        max_context_tokens = $SelectedMaxContextTokens
    }

    if ($SubscriptionMode -eq "claude_code") {
        $workerLlm["use_claude_code_subscription"] = $true
    } elseif ($SubscriptionMode -eq "codex") {
        $workerLlm["use_codex_subscription"] = $true
    } elseif ($SubscriptionMode -eq "antigravity") {
        $workerLlm["use_antigravity_subscription"] = $true
        # Pass along any Antigravity OAuth env vars if set
        $agSecret = [System.Environment]::GetEnvironmentVariable("ANTIGRAVITY_CLIENT_SECRET", "User")
        if (-not $agSecret) { $agSecret = $env:ANTIGRAVITY_CLIENT_SECRET }
        if ($agSecret) { $workerLlm["antigravity_client_secret"] = $agSecret }
        $agClientId = [System.Environment]::GetEnvironmentVariable("ANTIGRAVITY_CLIENT_ID", "User")
        if (-not $agClientId) { $agClientId = $env:ANTIGRAVITY_CLIENT_ID }
        if ($agClientId) { $workerLlm["antigravity_client_id"] = $agClientId }
    } elseif ($SubscriptionMode -eq "zai_code") {
        $workerLlm["api_base"] = "https://api.z.ai/api/coding/paas/v4"
        $workerLlm["api_key_env_var"] = $SelectedEnvVar
    } elseif ($SubscriptionMode -eq "minimax_code") {
        $workerLlm["api_base"] = "https://api.minimax.io/v1"
        $workerLlm["api_key_env_var"] = $SelectedEnvVar
    } elseif ($SubscriptionMode -eq "kimi_code") {
        $workerLlm["api_base"] = "https://api.kimi.com/coding"
        $workerLlm["api_key_env_var"] = $SelectedEnvVar
    } elseif ($SubscriptionMode -eq "teamagents_llm") {
        $workerLlm["api_base"] = $TeamAgentsLlmEndpoint
        $workerLlm["api_key_env_var"] = $SelectedEnvVar
    } elseif ($SelectedProviderId -eq "openrouter") {
        $workerLlm["api_base"] = "https://openrouter.ai/api/v1"
        $workerLlm["api_key_env_var"] = $SelectedEnvVar
    } else {
        $workerLlm["api_key_env_var"] = $SelectedEnvVar
    }

    $config | Add-Member -NotePropertyName "worker_llm" -NotePropertyValue $workerLlm -Force
    $config | ConvertTo-Json -Depth 4 | Set-Content -Path $TeamAgentsConfigFile -Encoding UTF8
    Write-Ok "done"
    Write-Color -Text "  ~/.teamagents/configuration.json (worker_llm section)" -Color DarkGray

    Write-Host ""
    Write-Ok "Worker model configured successfully."
    Write-Color -Text "  Worker agents will now use: $SelectedProviderId/$SelectedModel" -Color DarkGray
    Write-Color -Text "  Run this script again to change, or remove the worker_llm section" -Color DarkGray
    Write-Color -Text "  from ~/.teamagents/configuration.json to revert to the default." -Color DarkGray
    Write-Host ""
}


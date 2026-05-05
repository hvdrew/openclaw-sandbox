[CmdletBinding()]
param(
  [string]$Sandbox = "openclaw",
  [string]$Workspace,
  [string]$Template,
  [string]$DefaultModel = "openai-codex/gpt-5.5",
  [switch]$NoKit,
  [switch]$SkipPolicy,
  [switch]$SkipBootstrap,
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$KitPath = Join-Path $RepoRoot "kits\openclaw-bootstrap"
$InstallScript = Join-Path $KitPath "files\home\install-openclaw.sh"

function Invoke-CheckedCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command,

    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE`: $Command $($Arguments -join ' ')"
  }
}

if (-not $Workspace) {
  $Workspace = Join-Path $RepoRoot "sandbox"
}

if (-not (Test-Path -LiteralPath $Workspace)) {
  New-Item -ItemType Directory -Path $Workspace | Out-Null
}

if (-not (Test-Path -LiteralPath $InstallScript)) {
  throw "Missing install script: $InstallScript"
}

if ($Template -and $Template -match "[<>]") {
  throw "Template '$Template' contains placeholder characters. Replace it with a real image reference, for example: docker.io/merison/openclaw-sbx:test"
}

$existing = sbx ls 2>$null | Where-Object { $_ -match "^$([regex]::Escape($Sandbox))\s" }
if ($existing) {
  if (-not $Force) {
    throw "Sandbox '$Sandbox' already exists. Use a different -Sandbox name or pass -Force to remove and recreate it."
  }

  Write-Host "Removing existing sandbox '$Sandbox' because -Force was provided."
  Invoke-CheckedCommand "sbx" @("rm", $Sandbox, "-f")
}

if (-not $SkipPolicy) {
  Write-Host "Configuring sandbox network policy."
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "auth.openai.com,chatgpt.com,api.openai.com")
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "deb.nodesource.com,registry.npmjs.org,nodejs.org")
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "localhost:11434")
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "localhost:12434")
}

$createArgs = @("create", "--name", $Sandbox)

if ($Template) {
  $createArgs += @("--template", $Template)
}

if (-not $NoKit) {
  if (-not (Test-Path -LiteralPath $KitPath)) {
    throw "Missing kit path: $KitPath"
  }

  $createArgs += @("--kit", $KitPath)
}

$createArgs += @("shell", $Workspace)

Write-Host "Creating sandbox '$Sandbox'."
Invoke-CheckedCommand "sbx" $createArgs

if (-not $SkipBootstrap) {
  Write-Host "Copying latest OpenClaw bootstrap script."
  Invoke-CheckedCommand "sbx" @("cp", $InstallScript, "$Sandbox`:/home/agent/install-openclaw.sh")

  Write-Host "Running OpenClaw bootstrap script."
  Invoke-CheckedCommand "sbx" @(
    "exec",
    "--user", "root",
    "--env", "OPENCLAW_DEFAULT_MODEL=$DefaultModel",
    $Sandbox,
    "bash", "-lc",
    "chown agent:agent /home/agent/install-openclaw.sh && chmod 0755 /home/agent/install-openclaw.sh && sudo -u agent -E HOME=/home/agent bash -lc /home/agent/install-openclaw.sh"
  )
}

Write-Host ""
Write-Host "Sandbox '$Sandbox' is ready."
Write-Host "Next steps:"
Write-Host "  sbx run $Sandbox"
Write-Host "  openclaw-codex-login"
Write-Host "  openclaw chat"

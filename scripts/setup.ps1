[CmdletBinding()]
param(
  [string]$Sandbox = "openclaw",
  [string]$Workspace,
  [string]$Template = "docker.io/merison/openclaw-sbx:v0.1.0",
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

function Invoke-SandboxCreate {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$RequestedSandbox
  )

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  try {
    $output = & sbx @Arguments 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $output | ForEach-Object { Write-Host $_ }

  if ($exitCode -eq 0) {
    return $RequestedSandbox
  }

  $message = ($output | ForEach-Object { $_.ToString() }) -join "`n"
  if ($message -notmatch "already exists") {
    throw "Command failed with exit code $exitCode`: sbx $($Arguments -join ' ')"
  }

  $fallbackSandbox = "$RequestedSandbox-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  $retryArgs = @($Arguments)

  for ($i = 0; $i -lt ($retryArgs.Count - 1); $i++) {
    if ($retryArgs[$i] -eq "--name") {
      $retryArgs[$i + 1] = $fallbackSandbox
      break
    }
  }

  Write-Host ""
  Write-Host "Sandbox '$RequestedSandbox' appears to have stale runtime state."
  Write-Host "Retrying with '$fallbackSandbox'."
  Write-Host ""

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  try {
    $retryOutput = & sbx @retryArgs 2>&1
    $retryExitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  $retryOutput | ForEach-Object { Write-Host $_ }

  if ($retryExitCode -ne 0) {
    throw "Command failed with exit code $retryExitCode`: sbx $($retryArgs -join ' ')"
  }

  return $fallbackSandbox
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
$createSandbox = $true

if ($existing) {
  if ($Force) {
    Write-Host "Removing existing sandbox '$Sandbox' because -Force was provided."
    Invoke-CheckedCommand "sbx" @("rm", $Sandbox, "-f")
  } else {
    Write-Host "Sandbox '$Sandbox' already exists. Reusing it."
    $createSandbox = $false
  }
}

if (-not $SkipPolicy) {
  Write-Host "Configuring sandbox network policy."
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "auth.openai.com,chatgpt.com,api.openai.com")
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "deb.nodesource.com,registry.npmjs.org,nodejs.org")
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "localhost:11434")
  Invoke-CheckedCommand "sbx" @("policy", "allow", "network", "localhost:12434")
}

if ($createSandbox) {
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
  $Sandbox = Invoke-SandboxCreate $createArgs $Sandbox
} else {
  Write-Host "Skipping sandbox creation."
}

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

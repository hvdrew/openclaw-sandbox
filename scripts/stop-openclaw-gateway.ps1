# scripts/stop-openclaw-gateway.ps1

[CmdletBinding()]
param(
  [string]$Sandbox = "openclaw",
  [int]$Port = 18789,
  [switch]$KeepSandbox
)

Write-Host "Stopping OpenClaw Gateway process in SBX '$Sandbox'..."

sbx exec $Sandbox bash -lc "touch /tmp/openclaw-gateway-stop-$Port; pkill -f '[o]penclaw gateway' 2>/dev/null || true"

if ($LASTEXITCODE -ne 0) {
  Write-Host "Gateway process stop failed or sandbox was not reachable. Continuing."
}

Write-Host "Unpublishing dashboard port $Port if present..."
sbx ports $Sandbox --unpublish "$Port`:$Port" 2>$null

if (-not $KeepSandbox) {
  Write-Host "Stopping sandbox..."
  sbx stop $Sandbox 2>$null
} else {
  Write-Host "Keeping sandbox running."
}

Write-Host "Done."

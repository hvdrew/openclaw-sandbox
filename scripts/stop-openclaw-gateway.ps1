# scripts/stop-openclaw-gateway.ps1

param(
  [string]$Sandbox = "openclaw",
  [switch]$KeepSandbox
)

Write-Host "Stopping OpenClaw Gateway process..."

sbx exec $Sandbox bash -lc 'pkill -f "[o]penclaw gateway" 2>/dev/null || true'

if ($LASTEXITCODE -ne 0) {
  Write-Host "Gateway process stop failed or sandbox was not reachable. Continuing."
}

if (-not $KeepSandbox) {
  Write-Host "Stopping sandbox..."
  sbx stop $Sandbox 2>$null
} else {
  Write-Host "Keeping sandbox running."
}

Write-Host "Done."

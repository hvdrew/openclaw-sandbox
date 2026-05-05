# scripts/stop-openclaw.ps1

param(
  [string]$Sandbox = "openclaw",
  [switch]$KeepSandbox
)

$bashScript = @'
set -u

echo "Stopping OpenClaw Gateway..."

if command -v openclaw >/dev/null 2>&1; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 10s openclaw gateway stop >/dev/null 2>&1 || true
  else
    openclaw gateway stop >/dev/null 2>&1 || true
  fi
fi

pkill -f "openclaw gateway" >/dev/null 2>&1 || true

echo "Gateway stop command completed."
'@ -replace "`r", ""

$bytes = [System.Text.Encoding]::UTF8.GetBytes($bashScript)
$b64 = [Convert]::ToBase64String($bytes)

$remoteCommand = "printf '%s' '$b64' | base64 -d > /tmp/stop-openclaw-gateway.sh && chmod +x /tmp/stop-openclaw-gateway.sh && /tmp/stop-openclaw-gateway.sh"

Write-Host "Stopping gateway inside sandbox '$Sandbox'..."

sbx exec $Sandbox bash -lc $remoteCommand

if ($LASTEXITCODE -ne 0) {
  Write-Host "Gateway stop command failed or sandbox was not reachable. Continuing..."
}

if (-not $KeepSandbox) {
  Write-Host "Stopping sandbox '$Sandbox'..."
  sbx stop $Sandbox
} else {
  Write-Host "Keeping sandbox '$Sandbox' running."
}

Write-Host ""
Write-Host "Done."

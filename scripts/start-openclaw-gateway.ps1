# scripts/start-openclaw-gateway.ps1

[CmdletBinding()]
param(
  [string]$Sandbox = "openclaw",
  [int]$Port = 18789
)

# This runs INSIDE the sandbox.
$remoteBash = @'
PORT="__PORT__"
TOKEN="$(openssl rand -hex 32)"

echo ""
echo "Gateway token: $TOKEN"
echo "Dashboard: http://localhost:${PORT}/?token=$TOKEN"
echo "Dashboard: http://127.0.0.1:${PORT}/?token=$TOKEN"
echo ""

openclaw gateway --bind lan --port "$PORT" --auth token --token "$TOKEN"
'@ -replace "__PORT__", $Port -replace "`r", ""

$remoteB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remoteBash))

# This runs in the NEW PowerShell window.
$gatewayScript = @"
Write-Host ""
Write-Host "Starting OpenClaw Gateway inside SBX '$Sandbox'..."
Write-Host "Leave this window open while using the dashboard."
Write-Host ""

sbx exec $Sandbox bash -lc "printf '%s' '$remoteB64' | base64 -d | bash"

Write-Host ""
Write-Host "OpenClaw Gateway exited."
Read-Host "Press Enter to close this window"
"@

$tmpScript = Join-Path $env:TEMP "openclaw-gateway-runner-$Sandbox.ps1"
Set-Content -Path $tmpScript -Value $gatewayScript -Encoding UTF8

Write-Host "Opening OpenClaw Gateway terminal..."
Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tmpScript

Write-Host "Waiting for gateway startup..."
Start-Sleep -Seconds 8

Write-Host "Publishing dashboard port..."

for ($i = 1; $i -le 20; $i++) {
  sbx ports $Sandbox --publish "$Port`:$Port" 2>$null

  if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Port published:"
    sbx ports $Sandbox
    Write-Host ""
    Write-Host "Use the token printed in the gateway terminal."
    Write-Host "Dashboard:"
    Write-Host "http://localhost:$Port/"
    Write-Host "http://127.0.0.1:$Port/"
    exit 0
  }

  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Could not publish port $Port."
Write-Host "If the gateway terminal is still running, try manually:"
Write-Host "sbx ports $Sandbox --publish $Port`:$Port"

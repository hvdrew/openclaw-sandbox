# scripts/start-openclaw-gateway.ps1

$Sandbox = "openclaw"
$Port = 18789

# This runs INSIDE the sandbox.
$remoteBash = @'
TOKEN="$(openssl rand -hex 32)"

echo ""
echo "Gateway token: $TOKEN"
echo "Dashboard: http://localhost:18789/?token=$TOKEN"
echo "Dashboard: http://127.0.0.1:18789/?token=$TOKEN"
echo ""

openclaw gateway --bind lan --port 18789 --auth token --token "$TOKEN"
'@ -replace "`r", ""

$remoteB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($remoteBash))

# This runs in the NEW PowerShell window.
$gatewayScript = @"
Write-Host ""
Write-Host "Starting OpenClaw Gateway inside SBX..."
Write-Host "Leave this window open while using the dashboard."
Write-Host ""

sbx exec $Sandbox bash -lc "printf '%s' '$remoteB64' | base64 -d | bash"

Write-Host ""
Write-Host "OpenClaw Gateway exited."
Read-Host "Press Enter to close this window"
"@

$tmpScript = Join-Path $env:TEMP "openclaw-gateway-runner.ps1"
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
    Write-Host "http://localhost:18789/"
    Write-Host "http://127.0.0.1:18789/"
    exit 0
  }

  Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Could not publish port 18789."
Write-Host "If the gateway terminal is still running, try manually:"
Write-Host "sbx ports openclaw --publish 18789:18789"

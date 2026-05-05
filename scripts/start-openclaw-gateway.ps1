# # scripts/start-openclaw-gateway.ps1

# $Sandbox = "openclaw"
# $Port = 18789
# $MaxAttempts = 5
# $RetryDelaySeconds = 8

# $bashScript = @'
# set -u

# PORT="18789"
# BIND="lan"

# mkdir -p "$HOME/.openclaw/logs"

# TOKEN_FILE="$HOME/.openclaw/gateway-token.txt"
# LOG_FILE="$HOME/.openclaw/logs/gateway-sbx.log"

# if [ ! -s "$TOKEN_FILE" ]; then
#   if command -v openssl >/dev/null 2>&1; then
#     openssl rand -hex 32 > "$TOKEN_FILE"
#   else
#     cat /proc/sys/kernel/random/uuid | tr -d "-" > "$TOKEN_FILE"
#   fi
#   chmod 600 "$TOKEN_FILE"
# fi

# TOKEN="$(cat "$TOKEN_FILE")"

# # Stop any old gateway process without failing the script.
# if command -v timeout >/dev/null 2>&1; then
#   timeout 10s openclaw gateway stop >/dev/null 2>&1 || true
# else
#   openclaw gateway stop >/dev/null 2>&1 || true
# fi

# pkill -f "openclaw gateway" >/dev/null 2>&1 || true
# sleep 1

# # Start gateway in background.
# nohup openclaw gateway \
#   --bind "$BIND" \
#   --port "$PORT" \
#   --auth token \
#   --token "$TOKEN" \
#   > "$LOG_FILE" 2>&1 < /dev/null &

# # Wait for gateway startup.
# READY=0
# STATUS="000"

# for i in $(seq 1 45); do
#   if grep -q "http server listening" "$LOG_FILE" 2>/dev/null; then
#     READY=1
#     break
#   fi

#   if command -v curl >/dev/null 2>&1; then
#     STATUS="$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || true)"
#     if [ "$STATUS" != "000" ]; then
#       READY=1
#       break
#     fi
#   fi

#   sleep 1
# done

# if [ "$READY" = "1" ]; then
#   echo ""
#   echo "OpenClaw Gateway started."
#   echo "Dashboard: http://127.0.0.1:$PORT/?token=$TOKEN"
#   echo "Token: $TOKEN"
#   echo "Log: $LOG_FILE"
#   echo "HTTP status: $STATUS"
#   echo ""
#   exit 0
# fi

# echo ""
# echo "OpenClaw Gateway may have failed to start."
# echo "Log output:"
# cat "$LOG_FILE" 2>/dev/null || echo "No log file created."
# exit 1
# '@ -replace "`r", ""

# $bytes = [System.Text.Encoding]::UTF8.GetBytes($bashScript)
# $b64 = [Convert]::ToBase64String($bytes)

# $remoteCommand = "printf '%s' '$b64' | base64 -d > /tmp/start-openclaw-gateway.sh && chmod +x /tmp/start-openclaw-gateway.sh && /tmp/start-openclaw-gateway.sh"

# $Started = $false

# for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
#   Write-Host "Starting OpenClaw Gateway... attempt $attempt/$MaxAttempts"

#   sbx exec $Sandbox bash -lc $remoteCommand

#   if ($LASTEXITCODE -eq 0) {
#     $Started = $true
#     break
#   }

#   Write-Host "SBX/OpenClaw startup failed. Waiting $RetryDelaySeconds seconds before retry..."
#   Start-Sleep -Seconds $RetryDelaySeconds
# }

# if (-not $Started) {
#   throw "Failed to start OpenClaw Gateway after $MaxAttempts attempts."
# }

# # Publish localhost port on Windows. This is safe to rerun.
# sbx ports $Sandbox --publish "$Port`:$Port" 2>$null

# Write-Host ""
# Write-Host "Published ports:"
# sbx ports $Sandbox

# Write-Host ""
# Write-Host "Open:"
# Write-Host "http://127.0.0.1:18789/"

# scripts/start-openclaw-gateway.ps1

$Sandbox = "openclaw"
$Port = 18789

# Make sure the Windows localhost port is published.
sbx ports $Sandbox --publish "$Port`:$Port" 2>$null

Write-Host ""
Write-Host "Published ports:"
sbx ports $Sandbox

Write-Host ""
Write-Host "Starting OpenClaw Gateway in foreground..."
Write-Host "Leave this terminal open while using the dashboard."
Write-Host ""

$remoteCommand = @'
TOKEN="$(openssl rand -hex 32)"
echo ""
echo "Gateway token: $TOKEN"
echo "Dashboard: http://127.0.0.1:18789/?token=$TOKEN"
echo ""
openclaw gateway --bind lan --port 18789 --auth token --token "$TOKEN"
'@ -replace "`r", ""

$bytes = [System.Text.Encoding]::UTF8.GetBytes($remoteCommand)
$b64 = [Convert]::ToBase64String($bytes)

sbx exec $Sandbox bash -lc "printf '%s' '$b64' | base64 -d | bash"
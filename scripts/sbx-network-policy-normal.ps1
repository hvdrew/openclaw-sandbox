# scripts/sbx-network-policy-normal.ps1

[CmdletBinding()]
param(
  [string]$Sandbox = "openclaw"
)

sbx stop $Sandbox 2>$null

"2" | sbx policy reset --force
sbx policy set-default balanced

# Local model runtimes
sbx policy allow network "localhost:11434"
sbx policy allow network "localhost:12434"

# OpenAI web auth / ChatGPT auth, if needed
sbx policy allow network "auth.openai.com,chatgpt.com"

# Discord and bot related domains, if needed
sbx policy allow network "discord.com,gateway.discord.gg,cdn.discordapp.com,media.discordapp.net"

# Steam API for basic app integrations
sbx policy allow network "api.steampowered.com"

sbx policy ls --type network

Write-Host "Sandbox network policy set to custom/Balanced."

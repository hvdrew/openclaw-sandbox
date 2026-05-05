# Very rarely used - publishes ports that my personal instance utilizes for one reason or another
[CmdletBinding()]
param(
  [string]$Sandbox = "openclaw",
  [string[]]$Ports = @("5177:5177")
)

foreach ($Port in $Ports) {
  Write-Host "Publishing $Port for sandbox '$Sandbox'..."
  sbx ports $Sandbox --publish $Port
}

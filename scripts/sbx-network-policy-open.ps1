# scripts/sbx-network-policy-open.ps1

sbx stop openclaw 2>$null

"1" | sbx policy reset --force
sbx policy set-default allow-all

# Keep local model runtimes explicit
sbx policy allow network "localhost:11434"
sbx policy allow network "localhost:12434"

sbx policy ls --type network

Write-Host "Sandbox Network set to Open."

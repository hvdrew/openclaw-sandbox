#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
OPENCLAW_DEFAULT_MODEL="${OPENCLAW_DEFAULT_MODEL:-openai-codex/gpt-5.5}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"

log() {
  printf '[openclaw-setup] %s\n' "$*"
}

node_major_version() {
  if ! command -v node >/dev/null 2>&1; then
    return 1
  fi

  node -v | sed -E 's/^v([0-9]+).*/\1/'
}

ensure_node() {
  local major

  if major="$(node_major_version 2>/dev/null)" && [ "$major" -ge 22 ]; then
    log "Node $(node -v) is already available."
    return
  fi

  log "Installing Node.js 22."
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
}

ensure_openclaw() {
  if command -v openclaw >/dev/null 2>&1 && [ "${OPENCLAW_INSTALL_FORCE:-0}" != "1" ]; then
    log "OpenClaw is already available."
    return
  fi

  log "Installing OpenClaw ${OPENCLAW_VERSION}."
  sudo npm install -g "openclaw@${OPENCLAW_VERSION}"
}

write_openclaw_config() {
  log "Writing OpenClaw config for ${OPENCLAW_DEFAULT_MODEL}."

  python3 - "$OPENCLAW_CONFIG_PATH" "$OPENCLAW_DEFAULT_MODEL" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1]).expanduser()
model = sys.argv[2]
path.parent.mkdir(parents=True, exist_ok=True)

try:
    cfg = json.loads(path.read_text()) if path.exists() else {}
except Exception:
    cfg = {}

agents = cfg.setdefault("agents", {})
defaults = agents.setdefault("defaults", {})
defaults["model"] = {"primary": model}
defaults.setdefault("heartbeat", {})["every"] = "0m"

cfg["gateway"] = {"mode": "local"}

path.write_text(json.dumps(cfg, indent=2) + "\n")
print(path)
PY
}

write_helpers() {
  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  cat > "$bin_dir/openclaw-start-gateway" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-18789}"
TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}"

echo ""
echo "Gateway token: ${TOKEN}"
echo "Dashboard: http://localhost:${PORT}/?token=${TOKEN}"
echo "Dashboard: http://127.0.0.1:${PORT}/?token=${TOKEN}"
echo ""

exec openclaw gateway --bind lan --port "${PORT}" --auth token --token "${TOKEN}"
EOF

  cat > "$bin_dir/openclaw-codex-login" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

openclaw models auth login --provider openai-codex
openclaw config set agents.defaults.model.primary "${OPENCLAW_DEFAULT_MODEL:-openai-codex/gpt-5.5}"
openclaw config set agents.defaults.heartbeat.every "0m"
EOF

  rm -f "$bin_dir/openclaw-tui"
  chmod 0755 "$bin_dir/openclaw-start-gateway" "$bin_dir/openclaw-codex-login"

  local bashrc="$HOME/.bashrc"
  local marker="# OpenClaw sandbox helper PATH"
  touch "$bashrc"

  if ! grep -Fq "$marker" "$bashrc"; then
    cat >> "$bashrc" <<EOF

${marker}
export PATH="\$HOME/.local/bin:\$PATH"
EOF
  fi
}

main() {
  ensure_node
  ensure_openclaw
  write_openclaw_config
  write_helpers

  log "Bootstrap complete."
  log "Run 'openclaw-codex-login' inside the sandbox to complete Codex auth."
  log "Then run 'openclaw chat'."
  log "Use './scripts/start-openclaw-gateway.ps1' from the host for the dashboard."
}

main "$@"

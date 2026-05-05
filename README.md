TODO: This doc is out of date. I should definitely spruce it up after getting the scripts finished.  
TODO: Scripts need finishing/refactoring  
TODO: Need a custom image for the docker sandbox so it can start with a setup.sh script ready to run  

## General
This repo contains everything needed to get a docker sandbox setup for running OpenClaw with local models or with things like ChatGPT Codex. The priority here is security and isolation from the host system, without losing access to hardware. It uses the newer docker sandboxes feature to accomplish these goals.

Note that while I initially was focused on running this with Local models, the performance was dissappointing. I have since been using it with OpenAI's Codex (openai-codex/gpt-5.5). With heartbeat disabled I've had no issues getting some stuff done within the limits of the 20 dollar tier, so that's nice.

This is all inspired by [this blog post](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/) from docker.com, although the guide itself is based on stale info and required a migration to the new `sbx` CLI that docker offers. The `docker sandbox` syntax has been deprecated for some time.

## Notes on setup
This is intended to be ran on Windows 11. You very likely need to have the following set up:
- WSL2, plus enabling WSL2 functionality in Docker Desktop's settings
- Set up Ollama for your machine. If you're fancy you can swap this component out for Llama.cpp or use Docker Model Runner, but Ollama worked fine for me.
    - Feel free to skip this if you're just going to run it with cloud models
- Get the `sbx` CLI installed if you haven't yet (`winget install -h Docker.sbx`)
    - Make sure to log in as well, then select Balanced for the network mode. `sbx login`
- Enable Docker Model Runner (settings -> Features in Development -> Enable). Might also want to enable GPU usage for inference.
    - This was required for the initial guide but I'm about 99% sure it's no longer needed. I'll test it some day.

Fair warning, using this with a local model requires a decent amount of VRAM to work well (or possibly at all). My setup has 16GB of VRAM (RTX 2070s Ti). All in all local models were fun to mess with, but it really wasn't as capable as I was hoping it would be. You win for now, AI companies :(

## Quick Start
First pull the model you're using (if relevant):
```bash
# Replace this with whatever model you want. Remember your choice for later.
ollama pull gpt-oss:20b
```

Prepare our network to interface with the sandbox and nodesource.com
```bash
sbx policy allow network localhost:11434
sbx policy allow network deb.nodesource.com
```

Then create and run the sandbox container. Run this directly from whatever directory you want OpenClaw to work within:
```bash
sbx create shell . --name openclaw
sbx run openclaw
```

When done with the commands above you should be connected to the sandbox session. Validate that we can reach Ollama by running the following in the sandbox terminal:
```bash
curl http://host.docker.internal:11434/v1/models
```


We should be all set to move forward. Run this last set of commands to get started:
```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates gnupg

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# both of these should now work:
node -v
npm -v

sudo npm install -g openclaw@latest
openclaw setup

# SKIP THIS ACTUALLY Finally, configure openclaw:
# openclaw configure
```

Finally, update the config to use the desired model. Make sure to update the model if you need to in the text below before actually running it.
```bash
#MODEL="gpt-oss:20b"
MODEL="qwen3-coder-openclaw"
python3 - <<EOF
import json, os
from pathlib import Path

model = os.environ.get("MODEL", "$MODEL")
p = Path.home() / ".openclaw" / "openclaw.json"
p.parent.mkdir(parents=True, exist_ok=True)

cfg = {}
if p.exists():
    try:
        cfg = json.loads(p.read_text())
    except Exception:
        cfg = {}

cfg["models"] = cfg.get("models", {})
cfg["models"]["mode"] = "merge"
cfg["models"]["providers"] = cfg["models"].get("providers", {})
cfg["models"]["providers"]["ollama"] = {
    "baseUrl": "http://host.docker.internal:11434/v1",
    "apiKey": "ollama",
    "api": "openai-completions",
    "models": [{
        "id": model,
        "name": f"{model} via host Ollama",
        "reasoning": False,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": 32768,
        "maxTokens": 8192
    }]
}

cfg["agents"] = cfg.get("agents", {})
cfg["agents"]["defaults"] = cfg["agents"].get("defaults", {})
cfg["agents"]["defaults"]["model"] = {"primary": f"ollama/{model}"}
cfg["gateway"] = {"mode": "local"}

p.write_text(json.dumps(cfg, indent=2))
print(p)
EOF
```

From there you should be able to start it up!
```bash
openclaw tui --local
```

To run the web UI instead, you'll need to update the ports to publish the web UI port from outside of the sandbox. Note there is an additional auth step required for the UI, and I never got it working. You'll probably need to open an additional port or something.

Run this from a separate terminal:
```bash
sbx ports openclaw --publish 18789:18789
```

Then run the web GUI with the following:
```bash
TOKEN="$(openssl rand -hex 32)"
openclaw gateway --bind lan --port 18789 --auth token --token "$TOKEN"
```

You'll find the web UI at http://localhost:18789

> TODO: Get a setup script built and publish this as a container image

## Wiping the State
If you wanted to wipe the sandboxes internal state you could accomplish this by running the following:
```bash
sbx rm openclaw -f 2>$null
```
> NOTE: This is fully destructive and will completely wipe the container. Do not run unless you want to destroy and start from scratch.

# Finding a Better Model
The model I started with seemed fine, but I wanted to try another option out. The OSS 20b model had issues with handling text and file modifications pretty much immediately.

As a first substitute I'm going to try Qwen3-coder:30b with some slightly custom settings. If you want to follow along, run this:
```bash
ollama pull qwen3-coder:30b

@'
FROM qwen3-coder:30b
PARAMETER num_ctx 32768
PARAMETER temperature 0.2
'@ | Set-Content .\Modelfile.openclaw

ollama create qwen3-coder-openclaw -f .\Modelfile.openclaw
```

This will add a model option for `qwen3-coder-openclaw` to the ollama list. Use it when setting up openclaw.

If this is too slow, the other best option is the gpt-OSS:20b, so I should just swap back.

## Actually setting up an edge model from OpenAI
Time to see what this can do. I do hate openAI, but their models are insanely capable compared to anything I can run on this machine, and they gave me a free month of Codex usage.

We can auth with codex instead of using the API offered by OpenAI to save ourselves from having to pay money. To do that, follow these instructions:
```bash
sbx policy allow network "auth.openai.com,chatgpt.com"

# enter the sandbox
sbx run openclaw

# start oauth login
openclaw models auth login --provider openai-codex

# set the default
openclaw config set agents.defaults.model.primary openai-codex/gpt-5.5

# Disable heartbeat to avoid burning our usage
openclaw config set agents.defaults.heartbeat.every "0m"

# Launch web UI
TOKEN="$(openssl rand -hex 32)"
echo "Gateway token: $TOKEN"
openclaw gateway --bind lan --port 18789 --auth token --token "$TOKEN"

# OR run it in terminal
openclaw tui
```


# Scripts
This project got more complicated than I had hoped, go figure. These scripts are to help make the process a bit easier to recall/work within.

## Start/Stop Gateway
These are likely a bit overkill, but I hate having to remember a bunch of docker commands. That goes double since we are dealing with a new `sbx` syntax. Use them to fully start or fully stop the application.
```powershell
./scripts/start-openclaw-gateway.ps1
./scripts/stop-openclaw-gateway.ps1
```

## Network Policy Scripts
These two scripts are for flipping between network policy modes if needed. The normal script will set the network to allow only a short list of domains, plus the standard dev domains docker includes in the default balanced preset. I've added a few things here and there to get some of my projects working, none of which should be suspect. Give the script a look and modify it to your heart's content, just in case.

The open script will, as the name implies, set the network policies to fully open. This is not the smartest thing to do, but is all but necessary when working on things like scrapers/bots. On the bright side this doesn't really expose anything important aside from whatever exists on the OpenClaw sandbox machine, such as API keys and other secrets it might be using. Don't share sensitive stuff with this thing, it can't actually think and it is very possible that someone could get it to expose anything it might know.

No arguments are required for either script.
```powershell
./scripts/sbx-network-policy-normal.ps1  # sets normal policy rules
./scripts/sbx-network-policy-open.ps1    # sets open policy rules
```

### Publish Ports
Some apps that are built by OpenClaw expose ports that we want to access on the host machine. To do this, we must publish the port via `sbx`. Again, I hate remembering stuff, so I have a basic script set up to republish anything I commonly need in case the network profile is reset.

```powershell
./scripts/publish-ports.ps1
```

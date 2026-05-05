## General
This repo contains everything needed to get a docker sandbox setup for running OpenClaw with local models or with things like ChatGPT Codex. The priority here is security and isolation from the host system, without losing access to hardware. It uses the newer docker sandboxes feature to accomplish these goals.

Note that while I initially was focused on running this with Local models, the performance was dissappointing. I have since been using it with OpenAI's Codex (openai-codex/gpt-5.5). With heartbeat disabled I've had no issues getting some stuff done within the limits of the 20 dollar tier, so that's nice.

This is all inspired by [this blog post](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/) from docker.com, although the guide itself is based on stale info and required a migration to the new `sbx` CLI that docker offers. The `docker sandbox` syntax has been deprecated for some time.


### Further Integration
To take this further you should consider setting up a Channel within OpenClaw once it's up and running. I have mine set up as a Discord bot to allow for easy communication from anywhere. It is a full moderator on it's own server and has really been cool to work with.

I'd highly recommend either discord or WhatsApp to get the most out of this setup.


## Notes on setup
This is intended to be ran on Windows 11. You very likely need to have the following set up:
- WSL2, plus enabling WSL2 functionality in Docker Desktop's settings
- Get the `sbx` CLI installed if you haven't yet (`winget install -h Docker.sbx`)
- Make sure to log in as well, then select Balanced for the network mode. `sbx login`
- If you're using local models, set up Ollama for your machine. If you're fancy you can swap this component out for Llama.cpp or use Docker Model Runner, but Ollama worked fine for me.
- Docker Model Runner is no longer required for the default setup. This project now defaults to OpenAI Codex.

Fair warning, using this with a local model requires a decent amount of VRAM to work well (or possibly at all). My setup has 16GB of VRAM (RTX 4070s Ti). All in all local models were fun to mess with, but it really wasn't as capable as I was hoping it would be. You win for now, AI companies :(


## Quick Start
The project uses a custom sandbox image with Node 22, OpenClaw, and a setup script baked in. The setup script creates the `sbx` instance, copies the latest bootstrap script into it, configures OpenClaw for `openai-codex/gpt-5.5`, and disables heartbeat so it doesn't burn usage for no reason.

This was last tested against OpenClaw `2026.5.4 (325df3e)`.

Recommended/default setup:
```powershell
./scripts/setup.ps1 -Template "docker.io/merison/openclaw-sbx:v0.1.0"
```

That uses the project `sandbox` directory as the workspace and names the sandbox `openclaw`.

If you want to customize the sandbox name and workspace you can do so via arguments, like so:
```powershell
$testWorkspace = Join-Path $env:TEMP "openclaw-sbx-test-workspace"

./scripts/setup.ps1 `
  -Sandbox openclaw-build-test `
  -Workspace $testWorkspace `
  -Template "docker.io/merison/openclaw-sbx:v0.1.0" `
  -SkipPolicy
```

Once setup finishes, connect to the sandbox:
```powershell
# substitute your sandbox name if you didn't use the default:
sbx run openclaw
```

Then authenticate with Codex inside the sandbox:
```bash
openclaw-codex-login
```

From there you should be able to start it up:
```bash
openclaw chat
```

To run the dashboard instead, use the host script. It'll open the gateway in a new PowerShell window and publish the required port for you. Run this back on your host machine, not in the sandbox:
```powershell
./scripts/start-openclaw-gateway.ps1
```

You'll find the dashboard at http://localhost:18789 and the token will be printed in the gateway terminal.


## Destroying the Sandbox
If you wanted to wipe the sandboxes internal state you could accomplish this by running the following:
```powershell
sbx rm openclaw -f 2>$null
```
> NOTE: This is fully destructive and will completely wipe the container. Do not run unless you want to destroy and start from scratch.


# Finding a Better Model
The model I started with seemed fine, but I wanted to try another option out. The OSS 20b model had issues with handling text and file modifications pretty much immediately.

As a first substitute I tried Qwen3-coder:30b with some slightly custom settings. If you want to try it out, run the following to set up the customizations from the Modelfile in this project:
```bash
ollama pull qwen3-coder:30b
ollama create qwen3-coder-openclaw -f .\Modelfile.openclaw
```

This will add a model option for `qwen3-coder-openclaw` to the ollama list. Use it when setting up openclaw.

Between this and gpt-OSS:20b, I feel like I had a better experience with gpt-OSS, but it's tough to say considering how slow each of them are locally.

## OpenAI Codex
I do hate openAI, but their models are insanely capable compared to anything I can run on this machine, and they gave me a free month of Codex usage.

Codex is now the default setup path for this project, so getting this set up is essentially just a matter of authenticating, which you can do by running the openclaw-codex-login helper in the sandbox:
```bash
openclaw-codex-login
```

After that, run OpenClaw in terminal mode with:
```bash
openclaw chat
```


# Scripts
This project got more complicated than I had hoped, go figure. These scripts are to help make the process a bit easier to recall/work within.

## Start/Stop Gateway
These are likely a bit overkill, but I hate having to remember a bunch of docker commands. That goes double since we are dealing with a new `sbx` syntax. Use these to fully start or fully stop the application.
```powershell
./scripts/start-openclaw-gateway.ps1
./scripts/stop-openclaw-gateway.ps1

# If you used a custom sandbox name:
./scripts/start-openclaw-gateway.ps1 -Sandbox openclaw-build-test
./scripts/stop-openclaw-gateway.ps1 -Sandbox openclaw-build-test
```

## Network Policy Scripts
These two scripts are for flipping between network policy modes if needed. The normal script will set the network to allow only a short list of domains, plus the standard dev domains docker includes in the default balanced preset. I've added a few things here and there to get some of my projects working, none of which should be suspect. Give the script a look and modify it to your heart's content, just in case.

The open script will, as the name implies, set the network policies to fully open. This is not the smartest thing to do, but is all but necessary when working on things like scrapers/bots. On the bright side this doesn't really expose anything important aside from whatever exists on the OpenClaw sandbox machine, such as API keys and other secrets it might be using. Don't share sensitive stuff with this thing, it can't actually think and it is very possible that someone could trick it into exposing anything it might know.

No arguments are required for either script, but you can pass a sandbox name if you're not using `openclaw`. The policy itself is global; the sandbox name is used so the script stops the correct sandbox before changing it.
```powershell
./scripts/sbx-network-policy-normal.ps1  # sets normal policy rules
./scripts/sbx-network-policy-open.ps1    # sets open policy rules

# If you used a custom sandbox name:
./scripts/sbx-network-policy-normal.ps1 -Sandbox openclaw-build-test
./scripts/sbx-network-policy-open.ps1 -Sandbox openclaw-build-test
```

### Publish Ports
Some apps that are built by OpenClaw expose ports that we want to access on the host machine. To do this, we must publish the port via `sbx`. Again, I hate remembering stuff, so I have a basic script set up to republish anything I commonly need in case the network profile is reset.

```powershell
./scripts/publish-ports.ps1

# If you used a custom sandbox name or need custom ports:
./scripts/publish-ports.ps1 -Sandbox openclaw-build-test
./scripts/publish-ports.ps1 -Sandbox openclaw-build-test -Ports @("5177:5177", "3000:3000")
```

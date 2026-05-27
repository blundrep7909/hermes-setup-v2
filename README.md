# Hermes Setup v2

One Docker container — **Hermes Agent** + **AionUI WebUI**. Built for low-resource VPS (tested on RumahWeb 2GB RAM).

**Available as a pre-built image on ghcr.io** — no build step needed. Just pull and run.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  ONE CONTAINER (network_mode: host)                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ghcr.io/blundrep7909/hermes-setup-v2:latest        │    │
│  │  ┌──────────────────┐  ┌─────────────────────────┐   │    │
│  │  │ Hermes Gateway   │  │ AionUI WebUI (port 3000)│   │    │
│  │  │ (s6 auto-start)  │  │ ┌─────────────────────┐ │   │    │
│  │  │ Telegram/Discord │  │ │ AionCore (Rust)     │ │   │    │
│  │  │ WhatsApp/Slack   │  │ │ Spawns hermes acp   │ │   │    │
│  │  └──────────────────┘  │ │ as subprocess       │ │   │    │
│  │                        │ └─────────────────────┘ │   │    │
│  │                        └─────────────────────────┘   │    │
│  │  ┌──────────────────────────────────────────────┐    │    │
│  │  │ Volume: hermes-data -> /opt/data              │    │    │
│  │  │  +-- .hermes/config.yaml  (Hermes config)     │    │    │
│  │  │  +-- config.yaml         (model override)     │    │    │
│  │  │  +-- aionui-backend.db   (AionCore DB)        │    │    │
│  │  │  +-- logs/               (container logs)     │    │    │
│  │  └──────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### How it Works

1. **s6-overlay** starts two services inside the container:
   - `main-hermes` — Hermes Gateway (messaging bots)
   - `main` — runs `start.sh` which launches AionUI WebUI
2. **start.sh** also runs `hermes config set` on boot using `HERMES_DEFAULT_MODEL` and `HERMES_DEFAULT_PROVIDER` env vars — this ensures the Hermes config always matches your desired model
3. **AionUI WebUI** serves the frontend SPA + REST API on port 3000
4. **AionCore** (Rust binary bundled with AionUI) handles API requests
5. When you select the **Hermes agent** in the WebUI, AionCore spawns `hermes acp` as a child process via the Agent Communication Protocol (ACP)
6. **Hermes ACP** reads config from `HERMES_HOME` (`/opt/data`) and uses OpenRouter for inference
7. The Hermes agent handshake reports available models, capabilities (image support), and current model to AionCore

### Key Concepts

- **Aion CLI** vs **Hermes** agent: AionCore registers two agents. "Aion CLI" is AionCore's built-in agent with its own model config. "Hermes" is the ACP subprocess that uses your Hermes config. Always select "Hermes" in the UI.
- **Model config is per-conversation**: If you start a conversation before configuring the model, that conversation keeps the old model. Start a new conversation after changing config.
- **Volume persistence**: All config, database, and logs live on the `hermes-data` Docker volume mounted at `/opt/data`. Removing the volume (`docker compose down -v`) wipes everything.

---

## Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 1 GB (idle) | 2 GB+ |
| Disk | 5 GB | 10 GB |
| Docker | 20.10+ with Compose v2 | Latest |
| OS | Linux (any with Docker) | Ubuntu 22.04+ |
| Access | Port 3000 open | Tailscale Funnel |

---

## Quick Start

### One-Command Install

```bash
curl -fsSL https://raw.githubusercontent.com/blundrep7909/hermes-setup-v2/main/install.sh | bash
```

On first run it will:
1. Copy `.env.example` to `.env`
2. Prompt you to edit `.env` and add your `OPENROUTER_API_KEY`
3. Run the script again

From then on it:
1. Pulls the pre-built image from `ghcr.io/blundrep7909/hermes-setup-v2:latest`
2. Starts the container
3. Generates an admin password

### Manual Setup

```bash
git clone https://github.com/blundrep7909/hermes-setup-v2.git
cd hermes-setup-v2
cp .env.example .env
nano .env   # set OPENROUTER_API_KEY
docker compose up -d
docker exec hermes-aionui /opt/aionui/aionui-web resetpass --data-dir /opt/data
```

### Login

Open **http://localhost:3000** (or your VPS IP).

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | from `resetpass` output |

### Select Hermes Agent

After login:
1. Click the agent selector (top-left, defaults to "Aion CLI")
2. Choose **"Hermes"** from the dropdown
3. The model should show **poolside/laguna-m.1:free** (or whatever you set in .env)

> **Why?** "Aion CLI" is AionCore's built-in agent — it does NOT use your Hermes config and does NOT support OpenRouter. Only the "Hermes" ACP agent reads your OpenRouter settings and model config.

---

## Commands

### Update

Pull the latest image and recreate the container (no data loss):

```bash
bash install.sh --update
# or:
docker compose pull && docker compose up -d
```

### Backup

Backup the persistent data volume (config, DB, logs):

```bash
bash install.sh --backup
# or:
bash scripts/backup.sh
```

Backup file is saved to `~/hermes-backups/hermes-backup-<date>.tar.gz`.

Restore with:

```bash
docker run --rm -v hermes-setup-v2_hermes-data:/data \
  -v ~/hermes-backups:/backup alpine \
  tar xzf /backup/hermes-backup-<date>.tar.gz -C /data
```

### Uninstall

Remove container, volume, image, and local files:

```bash
bash install.sh --uninstall
# or:
bash uninstall.sh
```

> **Warning:** The `--uninstall` flag (or `docker compose down -v`) deletes the `hermes-data` Docker volume. All conversations, config, and logs are permanently lost. Backup first if needed.

### Build and Push Updated Image

To rebuild the image and push a new version to ghcr.io (requires GitHub PAT with `write:packages` scope):

```bash
GITHUB_TOKEN=ghp_xxx bash scripts/build-and-push.sh
```

---

## VPS Deployment (RumahWeb)

### Option A: One-Command Install (Recommended)

```bash
# On VPS:
curl -fsSL https://raw.githubusercontent.com/blundrep7909/hermes-setup-v2/main/install.sh | bash
```

### Option B: Direct Pull

```bash
# On VPS:
git clone https://github.com/blundrep7909/hermes-setup-v2.git
cd hermes-setup-v2
cp .env.example .env
nano .env   # set OPENROUTER_API_KEY
docker compose up -d   # pulls pre-built image from ghcr.io
```

### Tailscale Funnel (HTTPS Access)

```bash
# Install Tailscale:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Expose port 3000 publicly via Funnel:
sudo tailscale funnel 3000

# Access via: https://<hostname>.ts.net
```

> **Note:** Tailscale Funnel gives you a public HTTPS URL even without a domain. Perfect for RumahWeb VPS which has no static domain.

---

## Container Management

```bash
# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker compose logs -f
docker compose logs --tail=50 hermes-aionui

# Shell access
docker exec -it hermes-aionui sh

# Run Hermes commands
docker exec -it hermes-aionui hermes setup
docker exec -it hermes-aionui hermes model
docker exec -it hermes-aionui hermes config set model <name>
docker exec -it hermes-aionui hermes config set provider <provider>

# Full reset (deletes ALL data -- config, DB, logs)
docker compose down -v
docker compose up -d

# Check HTTP status
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/

# Test Hermes CLI (non-interactive one-shot)
docker exec hermes-aionui hermes -z "Hello, what model are you using?"
```

---

## Environment Variables

### API Key (Required)

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `OPENROUTER_API_KEY` | — | **Yes** | OpenRouter API key for LLM inference |

### AionUI WebUI

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `PORT` | `3000` | No | HTTP port for the WebUI |
| `NODE_ENV` | `production` | No | Node environment |
| `AIONUI_ALLOW_REMOTE` | `true` | No | Bind to `0.0.0.0` (needed for VPS access) |
| `AIONUI_DATA_DIR` | `/opt/data` | No | AionCore data directory on the volume |

### Hermes Agent

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `HERMES_HOME` | `/opt/data` | No | Hermes home (config, logs, memory, skills) |
| `GATEWAY_ALLOW_ALL_USERS` | `true` | No | Allow all users in messaging gateway mode |
| `HERMES_DEFAULT_MODEL` | `poolside/laguna-m.1:free` | No | Default inference model (auto-set on boot via `hermes config set`) |
| `HERMES_DEFAULT_PROVIDER` | `openrouter` | No | Inference provider (auto-set on boot via `hermes config set`) |

### Provider Alternatives

You can use any provider supported by Hermes. Set `HERMES_DEFAULT_PROVIDER` and the corresponding API key:

| Provider | Env Var to Set | `HERMES_DEFAULT_PROVIDER` |
|----------|---------------|--------------------------|
| OpenRouter | `OPENROUTER_API_KEY` | `openrouter` |
| Anthropic | `ANTHROPIC_API_KEY` | `anthropic` |
| OpenAI | `OPENAI_API_KEY` | `openai` |
| Google Gemini | `GOOGLE_API_KEY` | `gemini` |
| Groq | `GROQ_API_KEY` | `groq` |
| GitHub Copilot | `GITHUB_TOKEN` | `copilot` |
| Nous Portal | Login via `hermes login` | `nous` |
| Local Ollama | Set in `config.yaml` | `custom` |

---

## Files

```
hermes-setup-v2/
+-- Dockerfile              # Multi-stage build (downloader + hermes-agent)
+-- docker-compose.yml      # Single-service compose config (pulls from ghcr.io)
+-- .env                    # API keys + config (gitignored)
+-- .env.example            # Template without keys
+-- .gitignore
+-- README.md               # This file
+-- docker/
|   +-- start.sh            # Entrypoint -- auto-configs Hermes model on boot
+-- scripts/
    +-- build-and-push.sh   # Rebuild + push to ghcr.io
    +-- backup.sh           # Backup data volume
```

---

## Troubleshooting

### "Model does not support image input"

You are using the **"Aion CLI"** agent (default). Switch to the **"Hermes"** agent in the UI dropdown. Only the Hermes ACP agent supports image uploads.

### Container logs show "No configured users detected"

The data volume is empty or was reset (e.g., after `docker compose down -v`). Login to `http://localhost:3000` and set up the admin account.

### HTTP 503 / Connection refused on first access

Container might still be starting. Wait 10-15 seconds. Check with:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
```

Expected response: `200`

### Wrong model shown in WebUI

The conversation was created before the model config was updated. Start a **new conversation** in the UI. The model is captured at conversation creation time.

### Hermes gateway double-start

The Hermes Gateway auto-starts via s6 `main-hermes` service. Do NOT run `hermes gateway run` manually in `start.sh` or via exec.

### Model not in available list

The Hermes ACP model list is fetched from OpenRouter's popular models. If your model isn't listed, use `/model <name>` in chat to set it manually.

### CRLF line endings in scripts

If you edit `docker/start.sh` on Windows, fix line endings:

```bash
sed -i 's/\r//' docker/start.sh
sed -i '1s/^\xEF\xBB\xBF//' docker/start.sh
```

### "Error: 'hermes model' requires an interactive terminal"

Use these alternatives inside the container:

```bash
# Non-interactive config:
hermes config set model <name>

# Check current model:
hermes config get model

# Check config file:
cat /opt/data/config.yaml
```

---

## Comparison: v1 (Hermes_Setup) vs v2 (This Repo)

| Aspect | v1 (Hermes_Setup) | v2 (This Repo) |
|--------|-------------------|----------------|
| Containers | 3 (Hermes + Open WebUI + AionUI) | 1 (all-in-one) |
| Frontend | Open WebUI (port 3000) | AionUI WebUI (port 3000) |
| AionUI | Separate container (port 3001) | Built into same container |
| AionUI build | From source (Rust + Node toolchain) | Pre-built tarball (binary only) |
| Hermes image | `ghcr.io/anomalyco/hermes-agent:0.14.11` | `nousresearch/hermes-agent:latest` |
| API mode | Hermes API server (port 8642) + auto-generated key | Direct ACP subprocess (no API server) |
| Auth | Auto-generated API key | OpenRouter API key |
| RAM usage | ~3 containers | 1 container |
| Setup complexity | High (interactive prompts, many scripts) | Low (copy .env, compose up) |
| Update | Built-in (--update flag) | `docker compose pull && docker compose up -d` |
| Target audience | Feature-rich multi-service | **Low-resource VPS (2GB RAM)** |

**Bottom line:** v1 is a full-featured multi-container stack with rollback, updates, and a doctor script. v2 is minimal, single-container, and designed specifically for low-resource VPS where every MB of RAM counts.

---

## License

MIT

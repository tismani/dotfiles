# Halo LLM gateway

LiteLLM is the only remote endpoint: `http://halo:4000/v1`. It is reachable
through Tailscale and requires a bearer key. llama-swap and Lemonade listen on
loopback only.

## First deployment

Create the LiteLLM secret on Halo before starting the service:

```sh
sudo install -d -m 0700 /var/lib/secrets
key="sk-$(openssl rand -hex 32)"
printf 'LITELLM_MASTER_KEY=%s\n' "$key" | sudo tee /var/lib/secrets/litellm.env >/dev/null
sudo chmod 0600 /var/lib/secrets/litellm.env
printf 'Save this key on Nightfury: %s\n' "$key"
```

Put the same key in Nightfury's Keychain so OMP can resolve it without storing
it in Nix:

```sh
security add-generic-password -U -a mani -s litellm-halo -w 'PASTE_KEY_HERE'
```

## Models

Download every configured model explicitly:

```sh
llm-model-pull all
```

Or pass `qwen3.8-27b`, `qwen3.6-35b-a3b`, or `muse-glimmer-30b`
individually. Models load on first request and remain resident. The llama-swap
matrix permits all three to coexist, so switching back does not reload weights
from disk.

The `*-lemonade` IDs are manual failure fallbacks. Stop llama-swap before
using one to avoid loading a duplicate copy:

```sh
sudo systemctl stop llama-swap
```

## Open WebUI

On the separate Open WebUI machine, add an OpenAI-compatible connection:

- URL: `http://halo:4000/v1`
- API key: the value of `LITELLM_MASTER_KEY`

The primary model IDs are `qwen3.8-27b`, `qwen3.6-35b-a3b`, and
`muse-glimmer-30b`.

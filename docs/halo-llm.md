# Halo LLM gateway

LiteLLM is the primary OpenAI-compatible API at `http://halo:4000/v1`. It
listens on `0.0.0.0:4000`, and the firewall opens TCP port 4000 on every
interface, including the local network and Tailscale. Use Halo's LAN or
Tailscale address in place of `halo` when that hostname does not resolve. This
is deliberately a database-free API deployment; LiteLLM's
Admin UI and Playground login are not configured.

llama-swap remains independently reachable at `http://halo:9292/v1`. Use that
direct endpoint if LiteLLM is unavailable or when diagnosing the inference
backend. Lemonade remains directly reachable on port 13305 for maintenance.

## Registered models

The gateway advertises these Lemonade model IDs:

| Model ID | Context | Vision | MTP |
| --- | ---: | :---: | --- |
| `Qwen3.6-35B-A3B-MTP-GGUF` | 1,010,000 | yes | embedded, 2 draft tokens |
| `Qwen3.8-27B-GGUF` | 1,000,000 | yes | embedded, 3 draft tokens |
| `NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF` | 1,048,576 | no | embedded, 3 draft tokens |
| `Gemma-4-26B-A4B-it-MTP-GGUF` | 262,144 | yes | external, 3 draft tokens |

The Qwen models use static factor-4 YaRN from a 262,144-token original context.
All four use symmetric Q8 KV caches, one sequence, AMD Flash Attention, direct
I/O, and full ROCm offload. The configured contexts are publisher ceilings, not
claims about retrieval quality at the end of those windows. See the
[Qwen3.6 model card](https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF),
[Qwen3.8 model card](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF),
[Nemotron model card](https://huggingface.co/unsloth/NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF),
and [Gemma 4 model card](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF).

The four models are members of one explicit exclusive llama-swap group. A
request for a different ID terminates the running backend before the new one is
allocated. The health-check timeout is 30 minutes so direct-I/O model loading
and million-token KV allocation are not prematurely killed.

## Model ownership

Lemonade remains enabled on `0.0.0.0:13305` for listing, downloading, and
maintaining its cache. TCP port 13305 is open on all interfaces and the endpoint
has no API key, just like llama-swap. Its
declarative model list keeps all four weights downloaded; download Gemma
manually with the command below before rebuilding so the model-sync service has
nothing to fetch. There is no boot preload service.
Before llama-swap starts, its systemd unit waits for `lemond` and runs
`lemonade unload`, ensuring Lemonade does not retain a model in system/GPU
memory.

Do not run `lemonade load` while a llama-swap backend is resident. If Lemonade
was used for an interactive model test, return ownership to the gateway with:

```sh
lemonade unload
sudo systemctl restart llama-swap
```

Lemonade cache updates may create a new Hugging Face snapshot directory. The
llama-swap paths in `hosts/halo/llm.nix` are deliberately absolute runtime
strings, so after updating weights verify the snapshot paths and update the Nix
file if the old snapshot was removed. They are not copied into the Nix store.

## Download the Gemma primary

The Gemma projector and external MTP draft are already cached at revision
`c099eb48e663fd284577b04978a94ffccb261841`. Download the missing 16.9 GB primary
as `mani` before rebuilding:

```sh
hf download unsloth/gemma-4-26B-A4B-it-GGUF \
  gemma-4-26B-A4B-it-UD-Q4_K_M.gguf \
  --revision c099eb48e663fd284577b04978a94ffccb261841
```

Verify all three Gemma files are readable:

```sh
gemma="$HOME/.cache/huggingface/hub/models--unsloth--gemma-4-26B-A4B-it-GGUF/snapshots/c099eb48e663fd284577b04978a94ffccb261841"
stat "$gemma/gemma-4-26B-A4B-it-UD-Q4_K_M.gguf" \
  "$gemma/mmproj-F16.gguf" \
  "$gemma/mtp-gemma-4-26B-A4B-it.gguf"
```

## Deploy

Rebuild Halo to generate the llama-swap YAML and systemd units:

```sh
sudo nixos-rebuild switch --flake ~/dotfiles#halo
systemctl status lemond llama-swap litellm --no-pager
systemctl status lemonade-preload --no-pager
lemonade status --json
```

`lemonade-preload` should report that the unit does not exist. Lemonade's status
must show no loaded model after llama-swap starts.

The first activation generates a persistent LiteLLM master key outside the Nix
store. Read it locally, then use the value as the Bearer/API key in clients:

```sh
sudo sed -n 's/^LITELLM_MASTER_KEY=//p' /var/lib/litellm/environment
```

OMP reads that value from `LITELLM_API_KEY` and uses `openai-models-list`
discovery against LiteLLM. Open WebUI is connected automatically; its state,
backup, and restore procedure is documented in [openwebui.md](openwebui.md).
For other clients, configure an OpenAI-compatible connection with URL
`http://halo:4000/v1` and use the same key.

## Verify the generated configuration

Inspect the effective unit and generated YAML rather than only the source Nix:

```sh
systemctl cat llama-swap
config=$(systemctl show llama-swap -p ExecStart --value \
  | sed -n 's/.*--config \([^ ;]*\).*/\1/p')
sudo cat "$config"
```

Confirm the model list is exact:

```sh
curl --fail --silent http://127.0.0.1:9292/v1/models \
  | jq -r '.data[].id' | sort
```

Expected output:

```text
Gemma-4-26B-A4B-it-MTP-GGUF
NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF
Qwen3.6-35B-A3B-MTP-GGUF
Qwen3.8-27B-GGUF
```

Load each model sequentially with a short request:

```sh
for model in \
  Qwen3.6-35B-A3B-MTP-GGUF \
  Qwen3.8-27B-GGUF \
  NVIDIA-Nemotron-3.5-Lightning-30B-A3B-GGUF \
  Gemma-4-26B-A4B-it-MTP-GGUF
do
  curl --fail --silent http://127.0.0.1:9292/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK.\"}],\"max_tokens\":8,\"reasoning_effort\":\"none\"}" \
    | jq -r '.choices[0].message.content'
  pgrep -af llama-server
done
```

During the sequence, follow the combined gateway/backend logs:

```sh
journalctl -fu llama-swap
```

For every model, verify the log reports the configured context, `ROCm0` layer
offload, Q8 K and V caches, Flash Attention, and MTP initialization. Both Qwen
models must also load `mmproj-F16.gguf` and report YaRN scaling. Nemotron must
remain text-only. Gemma must load `mmproj-F16.gguf`, its separate
`mtp-gemma-4-26B-A4B-it.gguf` draft, and Q4 draft K/V caches. Between requests,
`pgrep` should show only the newly selected backend; the prior PID must
disappear before the next allocation.

Finally, check memory while each maximum context is allocated:

```sh
free -h
amdgpu_top
journalctl -u llama-swap -b | rg -i 'alloc|memory|error|fail|rocm|flash|mtp|kv'
```

An allocation failure is a deployment failure. Do not silently lower a declared
context; investigate memory availability or change the advertised contract
explicitly.

## LiteLLM unified endpoint

[`hosts/halo/llm.nix`](../hosts/halo/llm.nix) configures LiteLLM through the
native NixOS module. It defines the four preferred llama-swap routes, four
explicit `-lemonade` maintenance routes, and the cached `kokoro-v1` Lemonade TTS
route. No external YAML file or database is required. The `litellm-key` oneshot
service generates the master key on first activation and preserves it in
`/var/lib/litellm/environment`; it is never written to Git or the Nix store.
Chat routes default to `reasoning_effort: none` so clients that only display
`message.content` do not appear blank. Clients can override `reasoning_effort`
or `reasoning_format` per request when they support separate reasoning output.

Verify the unified model catalog and a completion after each deployment:

```sh
curl --fail --silent http://127.0.0.1:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_API_KEY" | jq -r '.data[].id' | sort
curl --fail --silent http://127.0.0.1:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen3.6-35B-A3B-MTP-GGUF","messages":[{"role":"user","content":"Reply with OK."}],"max_tokens":8,"reasoning_effort":"none"}' \
  | jq -r '.choices[0].message.content'
```

The unsuffixed model IDs should be used normally. Direct `-lemonade` requests
bypass llama-swap's one-model ownership, so first unload the active llama-swap
model or reserve those aliases for diagnostics. Both Halo upstream ports are
unauthenticated; restrict them at the network layer if the connected network is
not fully trusted. LiteLLM itself requires its generated key on every API
request, but traffic is plain HTTP; use a trusted LAN or encrypted overlay.

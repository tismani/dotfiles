# Halo LLM gateway

llama-swap exposes `http://halo:9292/v1` without authentication. It listens on
`0.0.0.0:9292`; the firewall opens TCP port 9292 on all interfaces, including the
local network and Tailscale. Use Halo's LAN IP in place of `halo` if the hostname
does not resolve locally. Lemonade remains on loopback with its default download
location and serving settings. LiteLLM is no longer configured.

## Deployment and migration

Rebuild Halo and Nightfury to apply the service and OMP changes. No API key,
secret environment file, or Keychain entry is required. Existing model files,
`/var/lib/llm-models`, old secret files, and old Keychain entries are left on disk.
No migration step downloads or deletes models.

## Download and register models

The gateway starts with `models = { };`. Its model list, including OMP discovery,
remains empty until entries are added to `hosts/halo/llm.nix` and Halo is rebuilt.
Lemonade downloads do not automatically register models in llama-swap.

1. As `mani` on Halo, use Lemonade's model manager to download a GGUF model, or
   run `lemonade list` followed by `lemonade pull MODEL_ID`. If the installed
   release names its CLI `lemonade-server`, use that command instead. See the
   [Lemonade CLI guide](https://lemonade-server.ai/docs/guide/cli/).
2. Locate the downloaded weights in Lemonade's default cache. For the usual
   user Hugging Face cache, run:

   ```sh
   find -L "$HOME/.cache/huggingface" -type f -name '*.gguf' -print
   ```

   If absent, inspect Lemonade's download output and service environment for its
   actual cache location. Do not set `extra_models_dir` or move files merely to
   register them. Ensure `mani` can read the chosen files and parent directories.
3. Uncomment the example in `hosts/halo/llm.nix`, choose a model ID, and replace
   `/absolute/path/model.gguf` with the downloaded GGUF's absolute path. Keep
   paths as strings in the command so Nix does not copy weights into the store.
   The example includes optional projector (`--mmproj`) and draft
   (`--model-draft`) paths; append them only for compatible files, with any
   model-specific speculative decoding flags required by llama.cpp.
4. Run `sudo nixos-rebuild switch --flake ~/dotfiles#halo`. Models load on demand
   with llama-swap's default swapping behavior. Unload models served directly by
   Lemonade before using the gateway if they compete for GPU memory.

## Clients and verification after deployment

OMP uses `auth: none` and `openai-models-list` discovery. For Open WebUI,
configure an OpenAI-compatible connection with URL `http://halo:9292/v1` and
leave the API key blank.

On Halo, check `systemctl status llama-swap` and
`journalctl -u llama-swap -b`. From a machine on the local network, run:

```sh
curl --fail http://halo:9292/v1/models
```

Use Halo's LAN IP if needed. The request must return an empty `data` array
initially. After registering a downloaded model and rebuilding, repeat it and
confirm the model ID appears, then restart OMP and confirm its Halo model picker
discovers that ID. Send a request to verify the weights load successfully.
Confirm port 4000 is no longer listening.

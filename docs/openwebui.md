# Open WebUI on Halo

Halo runs Open WebUI as a native NixOS service, defined in
[`hosts/halo/openwebui.nix`](../hosts/halo/openwebui.nix). It connects
**directly to llama-swap** on loopback (`http://127.0.0.1:9292/v1`), not to
LiteLLM. It is reachable at `http://10.1.3.246:8080` on the LAN and at
`http://halo:8080` over Tailscale.

## What is wired where

| Feature | Backend (llama-swap route) | Open WebUI setting |
| --- | --- | --- |
| Chat | Gemma 4 (default), Qwen3.6, Qwen3.8, Qwen3.8 TURBO, gufo Qwen3.8 DFlash2, gufo Flash-Next, gufo DeepSeek V4, Nemotron | `OPENAI_API_CONFIGS.model_ids` |
| Title, tags, follow-ups, image prompts | `Gemma-4-26B-A4B-it-MTP-GGUF` | `TASK_MODEL_EXTERNAL` |
| Image generation and editing | `gufo/Qwen-Image-2.1`, 1024x1024 | `IMAGE_*`, `IMAGES_*` |
| Video generation | `minimax-h3` via `/upstream/minimax-h3/v1` | **MiniMax H3 Video** Tool (see below) |
| Document embeddings | `Qwen3-Embedding-4B-GGUF` | `RAG_EMBEDDING_*` |
| Reranking | local CPU `BAAI/bge-reranker-v2-m3` | `RAG_RERANKING_*` |
| Speech-to-text | `gufo/Qwen3-ASR-1.7B` | `AUDIO_STT_*` |
| Text-to-speech | `gufo/Qwen3-TTS-12Hz-1.7B-CustomVoice`, voice `ryan` | `AUDIO_TTS_*` |
| Web search | SearXNG on `127.0.0.1:8888` | `WEB_SEARCH_*`, `SEARXNG_QUERY_URL` |

The chat picker lists only chat models. Image, speech, embedding, and video
routes are not chat models. Selecting one would send `/v1/chat/completions`,
which those Gufo servers reject. When adding or removing a llama-swap chat
model, also update `chatModels` in `hosts/halo/openwebui.nix`.

### Model residency

Gemma is both the default chat model and the task model because llama-swap's
matrix lets only Gemma stay resident beside Qwen Image (`gufo-image-gemma`).
Generating an image from a Gemma chat therefore does not evict anything. With
any other chat model, image generation evicts it and Gemma loads to write the
image prompt.

The embedder may stay resident beside every set except DeepSeek and MiniMax
H3. MiniMax H3 always runs alone, so a video request unloads the calling chat
model, and that model reloads for the reply.

## Nix is the source of truth

`ENABLE_PERSISTENT_CONFIG=False` makes Open WebUI read the Nix environment on
every start instead of the copy saved in `webui.db`. Edit
`hosts/halo/openwebui.nix` and rebuild to change any setting. Changes made under
**Admin Settings** apply only until the service restarts. Per-user and
per-model data is still kept: accounts, chats, knowledge, Workspace models,
Tools, and per-user settings.

## First start

1. Rebuild halo (`rebuild` on halo, or `rebuild-halo` from nightfury).
2. Immediately open `http://10.1.3.246:8080` and create the first account. It
   becomes admin. After that, self-signup is closed (`ENABLE_SIGNUP=False`).
   Further users are added under **Admin Panel > Users**, and stray signups
   land as `pending`.
3. Install the video tool (next section).

### Install the MiniMax H3 video tool

Open WebUI keeps Tools in `webui.db`, so this step cannot be done by Nix.

1. **Workspace > Tools > + (Create)**, then paste the contents of
   [`hosts/halo/openwebui/minimax_video.py`](../hosts/halo/openwebui/minimax_video.py).
   Save it with the ID `minimax_video`.
2. **Workspace > Models**, edit `Gemma-4-26B-A4B-it-MTP-GGUF`, tick
   **MiniMax H3 Video** under Tools, and save. Other chat models can enable it
   per chat from the **+** menu.
3. Ask Gemma for a video, for example "make a 5-second video of a red fox
   walking through snow". The tool shows progress while H3 loads and
   generates. A cold H3 load takes several minutes.

The finished MP4 is embedded in the chat as a data URI. Open WebUI renders
tool embeds in a sandboxed iframe without the session cookie, so an
authenticated file URL would not load there. A copy is also saved to Open
WebUI's file store with a **Download MP4** link, because Gufo deletes its own
job artifacts after one hour. The tool's valves set the canvas (`512x512` or
`1344x768`), the timeout, and the largest size that is embedded inline.

After pasting a newer version of the file, keep the same tool ID so the Gemma
model's attachment remains.

### Using images

Turn on **Image** in the chat input's feature toggles. Gemma then calls the
native `generate_image` or `edit_image` tool. Only `1024x1024` text-to-image
generation has passed the concurrent Gemma + Qwen Image memory test.
Image editing and larger sizes still need to be validated
(see [`halo-dual-model-memory.md`](halo-dual-model-memory.md)).

### Speech

TTS (the speaker icon on a reply) works over plain HTTP. Browsers allow
microphone capture only in a secure context (HTTPS or `localhost`), so dictation
needs an HTTPS front end, such as `tailscale serve`, or a browser on Halo itself.

## Where state lives

| Purpose | Path | Back up? |
| --- | --- | :---: |
| Declarative configuration | `hosts/halo/openwebui.nix`, `hosts/halo/llm.nix` | yes, through Git |
| Open WebUI state root | `/var/lib/open-webui` | yes |
| SQLite database (accounts, chats, tools, models) | `/var/lib/open-webui/data/webui.db` | yes |
| Uploads, generated media, vector indexes | `/var/lib/open-webui/data/` | yes |
| Reranker and tokenizer caches | `/var/lib/open-webui/hf_home/`, `/var/lib/open-webui/transformers_home/` | optional |
| Session-signing key | `/var/lib/open-webui-secrets/open-webui.env` (`WEBUI_SECRET_KEY`) | yes |
| SearXNG secret | `/var/lib/open-webui-secrets/searx.env` | optional |

The `open-webui-secrets` unit generates both secret files once, with mode
`0600`, and never rotates them. Changing `WEBUI_SECRET_KEY` logs everyone out
and can invalidate encrypted values in `webui.db`. Never commit these files.

The service uses systemd's `DynamicUser`, so `/var/lib/open-webui` may be a
symlink to `/var/lib/private/open-webui`. Resolve it with `readlink -f` rather
than hard-coding the private path.

Embeddings are tied to the embedding model. If `RAG_EMBEDDING_MODEL` changes,
re-index existing knowledge with **Admin Settings > Documents > Reindex
Knowledge Base Vectors**. The rebuilt indexes persist. Only the settings
page itself reverts to the Nix values.

## Inspect the running instance

```sh
systemctl status open-webui open-webui-secrets searx llama-swap --no-pager
systemctl cat open-webui
curl --fail --silent http://127.0.0.1:8080/api/config | jq
curl --fail --silent http://127.0.0.1:8888/search?q=nixos\&format=json | jq '.results | length'
curl --fail --silent http://127.0.0.1:9292/v1/embeddings \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen3-Embedding-4B-GGUF","input":"hello"}' \
  | jq '.data[0].embedding | length'   # 2560
journalctl -u open-webui -b --no-pager -n 200
```

## Back up

Stop Open WebUI while copying so SQLite can checkpoint its write-ahead log
(upstream [database guide](https://docs.openwebui.com/tutorials/maintenance/database/)).

```sh
BACKUP_DIR="$PWD/openwebui-backup-$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$BACKUP_DIR"

sudo systemctl stop open-webui

OPENWEBUI_STATE="$(readlink -f /var/lib/open-webui)"
case "$OPENWEBUI_STATE" in
  /var/lib/open-webui|/var/lib/private/open-webui) ;;
  *) printf 'Unexpected Open WebUI state path: %s\n' "$OPENWEBUI_STATE" >&2; exit 1 ;;
esac

sudo tar --acls --xattrs -C "$OPENWEBUI_STATE" \
  -czf "$BACKUP_DIR/openwebui-state.tar.gz" .
sudo install -m 0600 /var/lib/open-webui-secrets/open-webui.env \
  "$BACKUP_DIR/open-webui.env"
sudo chown -R "$(id -u):$(id -g)" "$BACKUP_DIR"

sudo systemctl start open-webui

(cd "$BACKUP_DIR" && sha256sum open-webui.env openwebui-state.tar.gz > SHA256SUMS)
tar -tzf "$BACKUP_DIR/openwebui-state.tar.gz" | grep -x './data/webui.db'
```

The backup contains conversations, uploads, accounts, and the session key.
Copy it to another disk or host over an encrypted channel, and record the
dotfiles revision and `flake.lock` used by the source host.

## Restore or migrate

Deploy the **same** dotfiles revision and `flake.lock` on the destination
first. Open WebUI runs database migrations at startup, and they may not be
reversible. Upgrade only after the restored instance works, and take a new
backup before upgrading.

```sh
cd ~/dotfiles
sudo nixos-rebuild switch --flake .#halo   # creates the state directories

BACKUP_DIR=/path/to/openwebui-backup-YYYYMMDD-HHMMSS
(cd "$BACKUP_DIR" && sha256sum -c SHA256SUMS)

sudo systemctl stop open-webui

OPENWEBUI_STATE="$(readlink -f /var/lib/open-webui)"
case "$OPENWEBUI_STATE" in
  /var/lib/open-webui|/var/lib/private/open-webui) ;;
  *) printf 'Unexpected Open WebUI state path: %s\n' "$OPENWEBUI_STATE" >&2; exit 1 ;;
esac

# Keep the destination's previous state for rollback instead of deleting it.
ROLLBACK_DIR="/var/lib/openwebui-pre-restore-$(date +%Y%m%d-%H%M%S)"
sudo install -d -m 0700 "$ROLLBACK_DIR/state"
sudo find "$OPENWEBUI_STATE" -mindepth 1 -maxdepth 1 \
  -exec mv -t "$ROLLBACK_DIR/state" -- {} +
sudo cp -a /var/lib/open-webui-secrets/open-webui.env "$ROLLBACK_DIR/" 2>/dev/null || true

sudo tar --acls --xattrs --no-same-owner \
  -xzf "$BACKUP_DIR/openwebui-state.tar.gz" -C "$OPENWEBUI_STATE"
sudo chown -R --reference="$OPENWEBUI_STATE" "$OPENWEBUI_STATE"/.
sudo install -o root -g root -m 0600 "$BACKUP_DIR/open-webui.env" \
  /var/lib/open-webui-secrets/open-webui.env

sudo systemctl start open-webui
```

Log in with an existing account and confirm that chats, knowledge collections,
and the MiniMax tool are present. If startup reports a migration error, stop
the service and restore the pre-migration backup instead of running manual SQL.
See the upstream
[manual migration guide](https://docs.openwebui.com/troubleshooting/manual-database-migration/).
Keep `$ROLLBACK_DIR` until login, chat, RAG, and image generation have all been
tested.

## Chat-only export is not a backup

**Settings > Data Controls > Export Chats** moves conversation history between
accounts. It does not capture uploads, knowledge, tools, accounts, or the
session key. Use the filesystem backup above for anything else.

## Security notes

llama-swap (`9292`) and Lemonade (`13305`) are unauthenticated, and Open WebUI
(`8080`) uses plain HTTP. All three are open on every interface. Use them only
on a trusted LAN or over Tailscale.

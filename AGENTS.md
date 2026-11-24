# AGENTS.md

Coding-agent guide for this three-host Nix flake. Read before editing.

## Repo

Single flake, three hosts:
- `nightfury` — macOS (nix-darwin, `aarch64-darwin`), the daily driver.
- `halo` — **AI-only host**: NixOS (`x86_64-linux`), Framework Desktop, AMD AI Max 300 (Strix Halo). Runs all local LLM inference.
- `ajwa` — NixOS (`x86_64-linux`), Intel, GNOME, LAN `192.168.100.171`. Never sleeps (`hosts/ajwa/power.nix`).

User `mani`, checkout `~/dotfiles`, remote `https://forgejo.internal.tismani.com/mani/dotfiles.git`.

## Layout

- `flake.nix` — the only place hosts are wired; three outputs: `darwinConfigurations.nightfury`, `nixosConfigurations.halo`, `nixosConfigurations.ajwa`.
- `hosts/nightfury/default.nix` — macOS host config.
- `hosts/halo/configuration.nix` — NixOS host entry; imports the halo modules below.
- `hosts/halo/llm.nix` — llama-swap + Lemonade/NPU stack (see AI stack).
- `hosts/halo/openwebui.nix` — Open WebUI + SearXNG; `hosts/halo/openwebui/` holds Open WebUI Tools.
- `hosts/halo/caddy.nix` — Caddy (cloudflare DNS plugin) serving `<name>.halo.tismani.com` from one wildcard cert; token from sops `cloudflare/api_token` (`secrets/halo.yaml`). Add `<name> = <port>;` to `proxied`; needs a Cloudflare `*.halo.tismani.com` record (DNS only) → halo's Tailscale IP `100.76.51.89` (tailnet + shared users only; shared users limited to `halo:443` in the Tailscale policy). The plugin `hash` must be refreshed (fakeHash + build on halo) when its version changes.
- `hosts/halo/monitoring.nix` — Prometheus (loopback :9090, 90d) + node_exporter (loopback :9100, `drm` for amdgpu) + Grafana (loopback :3000 → `grafana.halo.tismani.com`; admin password/secret key from sops `grafana/*`). Per-model llama.cpp metrics are scraped via `/upstream/<model>/metrics`; `upstream.ignorePaths` in `llm.nix` stops scrapes from loading models. Dashboards are provisioned read-only from `hosts/halo/grafana/llm.json` + pinned grafana.com 1860.
- `hosts/halo/desktop.nix`, `hosts/halo/flatpak.nix`, `hosts/halo/power.nix` — host extras.
- `hosts/halo/hardware-configuration.nix` — generated per-machine; do not hand-edit.
- `hosts/ajwa/configuration.nix` — NixOS host entry; imports `hosts/ajwa/power.nix` (no-sleep, own copy of halo's), `hosts/ajwa/media.nix` (nixflix: Prowlarr/Sonarr/Radarr/Jellyfin, qBittorrent/SABnzbd behind a WireGuard namespace, Recyclarr, Seerr, Maintainerr, plus nixpkgs Plex; see ajwa media stack), Tailscale (`sudo tailscale up` once), `hosts/ajwa/n8n.nix` (n8n in Docker on `:latest` — nixpkgs is too old for its DB; `docker-pull-latest` pulls and restarts updated containers on every switch; data in `/data/.state/n8n`; plus Stirling PDF on :8090, which n8n calls via the host port `http://192.168.100.171:8090` — container-to-container calls got 404s) and its generated `hardware-configuration.nix` (do not hand-edit).
- `modules/common/default.nix` — nix settings, GC, system packages (all hosts).
- `modules/common/stylix.nix` — Dracula theming.
- `modules/common/sops.nix` — sops-nix defaults (all hosts); `.sops.yaml` + `secrets/<host>.yaml` hold recipients and encrypted secrets. See `docs/secrets.md`.
- `modules/programs/fish.nix` — fish shell + aliases (all hosts).
- `home/mani/default.nix` — home-manager entry; imports the programs below.
- `home/mani/programs/` — per-program user config (omp, ssh, kitty, helix, herdr, lazy (lazydocker + lazygit), starship, superfile, yt-dlp).
- `home/mani/desktop/` — niri + noctalia, Linux-only, imported per-host.
- `docs/` — per-host bootstrap plus `docs/halo-llm.md`, `docs/halo-dual-model-memory.md`, `docs/openwebui.md`, `docs/herdr-quickstart.md`, `docs/secrets.md`.

## Halo AI stack

- **llama-swap = primary LLM runner.** NixOS systemd service `llama-swap`, listens `0.0.0.0:9292`, on-demand model swap. Model definitions live in `llamaSwapConfig` in `hosts/halo/llm.nix`.
- **Lemonade / lemond = NPU + TTS backend**, Nix-managed via `hardware.amd-npu` in `hosts/halo/llm.nix`, reachable `:13305`.
- **Open WebUI** — NixOS service in `hosts/halo/openwebui.nix`, `0.0.0.0:8080`, talks to llama-swap directly on loopback (chat, Qwen-Image, Qwen3 embeddings, gufo ASR/TTS) plus a loopback SearXNG on `:8888`. `ENABLE_PERSISTENT_CONFIG=False`: Nix env wins over the Admin UI. MiniMax H3 video is an Open WebUI Tool (`hosts/halo/openwebui/minimax_video.py`) imported by hand. Secrets are generated on halo under `/var/lib/open-webui-secrets`. See `docs/openwebui.md`.
- **OMP** (`home/mani/programs/omp.nix`, macOS-only) connects to **llama-swap directly** at `https://llm.halo.tismani.com/v1` (Caddy over Tailscale).
- Host GPU/ROCm tooling: `amdgpu_top`, `vulkan-tools`, `lmstudio`, `podman` (the halogen model runs via podman inside llama-swap).

## Add / remove a model

1. Edit `hosts/halo/llm.nix`: the `models` attrset (a `let` binding; Prometheus scrapes every llama-server `--metrics` / gufo `llm` model in it automatically) AND the `routing.router.settings.matrix` `vars`/`sets` (residency). Chat models also go in `chatModels` in `hosts/halo/openwebui.nix`.
2. Rebuild halo (reloads llama-swap).

## ajwa media stack

nixflix in `hosts/ajwa/media.nix`; every credential is a sops secret (see `docs/secrets.md`).
- **VPN:** only qBittorrent/SABnzbd run in the WireGuard namespace (kill switch). nixflix requires Prowlarr/Sonarr/Radarr all in or all out; they're out by choice.
- **qBittorrent login:** nixpkgs rewrites `qBittorrent.conf` on every start, so the WebUI hash is spliced in from sops `qbittorrent/password_hash` by an `ExecStartPre`. A password set in the WebUI won't survive a restart.
- **Seerr:** defining `seerr.radarr.<name>` / `seerr.sonarr.<name>` replaces nixflix's generated instance (option default, not merged) — restate `apiKey` and `isDefault`.
- **Maintainerr rules:** `nixflix.maintainerr.rules` is the source of truth. Groups are matched by `name`; unlisted groups are deleted and UI edits overwritten on each sync. Draft in the UI, export with `curl localhost:6246/api/rules`, port to Nix. Always set `arrAction` (option default is `DO_NOTHING`).
- **Reverse proxy:** own Caddy on :80 (not `nixflix.caddy`, which binds most services to 127.0.0.1 and breaks IP:port access). Add `<name> = <port>;` to `proxied` in `media.nix` for `<name>.home.lan`; each name also needs a router DNS entry (no wildcard). VPN-confined services need upstream `192.168.15.1`, not 127.0.0.1.
- **Stay on unstable:** nixflix only targets nixos-unstable, and Jellyfin/Seerr state in `/data/.state` can't be downgraded to 26.05's older versions.

## Build / verify / activate

- Verify WITHOUT activating:
  - nightfury: `nix build .#darwinConfigurations.nightfury.system`
  - halo: `nix build .#nixosConfigurations.halo.config.system.build.toplevel`
  - ajwa: `nix build .#nixosConfigurations.ajwa.config.system.build.toplevel`
  - Shared-module edits (`modules/`, `home/`) → build all hosts.
- NEVER run activation (`darwin-rebuild switch`, `nixos-rebuild switch`, or the fish `rebuild`/`rebuild-halo`/`rebuild-ajwa` aliases) unless explicitly asked — it mutates the live machine.
- Human workflow: fish `rebuild` (per-host switch, defined in `modules/programs/fish.nix`); `rebuild-halo` / `rebuild-ajwa` (macOS: rsyncs `~/dotfiles` to that host, runs `git add -A` there — rsync skips `.git` and flakes ignore untracked files — then builds and switches there).
- `nix flake update` is NOT routine — keep the checked-in `flake.lock`.

## Conventions / landmines

- Do NOT change `system.stateVersion` (halo `"25.11"`, ajwa `"26.05"`, home `"24.11"`) or overwrite `hosts/halo/hardware-configuration.nix` (see `docs/halo-bootstrap.md`).
- Platform-conditional code uses `pkgs.stdenv.hostPlatform.isDarwin` (see `home/mani/programs/omp.nix`, `home/mani/programs/ssh.nix`, `modules/programs/fish.nix`); guard new OS-specific config the same way.
- Hard-coded LAN IP `10.1.3.246` appears in `home/mani/programs/ssh.nix` (halo Host) and `hosts/halo/llm.nix` (Lemonade `allowedOrigins`) — update together if halo's address changes.
- SSH private keys are NOT in-repo (Bitwarden-managed; only `.pub` under `home/mani/programs/ssh.nix`). Never add private keys/tokens/secrets.
- Secrets go only in sops (`secrets/<host>.yaml`), referenced via `config.sops.secrets.<name>.path` (nixflix: `{ _secret = …; }`) — never as plaintext in `.nix`, which lands in the world-readable store.
- Stylix themes everything Dracula; `home/mani/programs/herdr.nix` hand-matches it (no stylix herdr target) — keep in sync.
- `home/mani/default.nix` sets `home.homeDirectory` via `lib.mkDefault "/home/mani"`; nightfury overrides with `lib.mkForce "/Users/mani"`.
- Comments here explain WHY (workarounds / upstream quirks) — preserve that style.
- `flake.nix` intentionally pins `nix-amd-ai` outside nixpkgs `follows` (re-hash/rebuild reason in its comment) — don't "clean up".

## Where changes go

- New CLI tool for all hosts → `modules/common/default.nix` (system) or `home/mani/default.nix` (user).
- New shell program → new file in `home/mani/programs/` + add to `home/mani/programs/default.nix` imports.
- Host-specific → that host's `hosts/<name>/` module.

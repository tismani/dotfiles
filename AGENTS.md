# AGENTS.md

Coding-agent guide for this three-host Nix flake. Read before editing.

## Repo

Single flake, three hosts:
- `nightfury` — macOS (nix-darwin, `aarch64-darwin`), the daily driver.
- `halo` — **AI-only host**: NixOS (`x86_64-linux`), Framework Desktop, AMD AI Max 300 (Strix Halo). Runs all local LLM inference.
- `ajwa` — NixOS (`x86_64-linux`), Intel, GNOME, LAN `10.1.2.182`. Never sleeps (`hosts/ajwa/power.nix`).

User `mani`, checkout `~/dotfiles`, remote `https://forgejo.internal.tismani.com/mani/dotfiles.git`.

## Layout

- `flake.nix` — the only place hosts are wired; three outputs: `darwinConfigurations.nightfury`, `nixosConfigurations.halo`, `nixosConfigurations.ajwa`.
- `hosts/nightfury/default.nix` — macOS host config.
- `hosts/halo/configuration.nix` — NixOS host entry; imports the halo modules below.
- `hosts/halo/llm.nix` — llama-swap + Lemonade/NPU stack (see AI stack).
- `hosts/halo/openwebui.nix` — Open WebUI + SearXNG; `hosts/halo/openwebui/` holds Open WebUI Tools.
- `hosts/halo/desktop.nix`, `hosts/halo/flatpak.nix`, `hosts/halo/power.nix` — host extras.
- `hosts/halo/hardware-configuration.nix` — generated per-machine; do not hand-edit.
- `hosts/ajwa/configuration.nix` — NixOS host entry; imports `hosts/ajwa/power.nix` (no-sleep, own copy of halo's), `hosts/ajwa/media.nix` (nixflix: Prowlarr/Sonarr/Radarr/Jellyfin, qBittorrent/SABnzbd behind a WireGuard namespace, Recyclarr, Seerr, Maintainerr; see ajwa media stack) and its generated `hardware-configuration.nix` (do not hand-edit).
- `modules/common/default.nix` — nix settings, GC, system packages (all hosts).
- `modules/common/stylix.nix` — Dracula theming.
- `modules/common/sops.nix` — sops-nix defaults (all hosts); `.sops.yaml` + `secrets/<host>.yaml` hold recipients and encrypted secrets. See `docs/secrets.md`.
- `modules/programs/fish.nix` — fish shell + aliases (all hosts).
- `home/mani/default.nix` — home-manager entry; imports the programs below.
- `home/mani/programs/` — per-program user config (omp, ssh, kitty, helix, herdr, lazydocker, starship, superfile, yt-dlp).
- `home/mani/desktop/` — niri + noctalia, Linux-only, imported per-host.
- `docs/` — per-host bootstrap plus `docs/halo-llm.md`, `docs/halo-dual-model-memory.md`, `docs/openwebui.md`, `docs/herdr-quickstart.md`, `docs/secrets.md`.
- `litellm-config.yaml` — root; docker LiteLLM config (see AI stack).

## Halo AI stack

- **llama-swap = primary LLM runner.** NixOS systemd service `llama-swap`, listens `0.0.0.0:9292`, on-demand model swap. Model definitions live in `llamaSwapConfig` in `hosts/halo/llm.nix`.
- **LiteLLM = docker container on a SEPARATE machine (NOT Nix, NOT on halo).** Reads root `litellm-config.yaml` (git-pulled into the container), serves `:4000` on its own host, master key from container env `LITELLM_MASTER_KEY`. Reaches halo's llama-swap over the LAN at `10.1.3.246:9292`; no LiteLLM port is opened on halo.
- **Lemonade / lemond = NPU + TTS backend**, Nix-managed via `hardware.amd-npu` in `hosts/halo/llm.nix`, reachable `:13305`. Still present; no longer fronted by LiteLLM.
- **Open WebUI** — NixOS service in `hosts/halo/openwebui.nix`, `0.0.0.0:8080`, talks to llama-swap directly on loopback (chat, Qwen-Image, Qwen3 embeddings, gufo ASR/TTS) plus a loopback SearXNG on `:8888`. `ENABLE_PERSISTENT_CONFIG=False`: Nix env wins over the Admin UI. MiniMax H3 video is an Open WebUI Tool (`hosts/halo/openwebui/minimax_video.py`) imported by hand. Secrets are generated on halo under `/var/lib/open-webui-secrets`. See `docs/openwebui.md`.
- **OMP** (`home/mani/programs/omp.nix`, macOS-only) connects to **llama-swap directly** at `http://10.1.3.246:9292/v1`, not LiteLLM.
- Host GPU/ROCm tooling: `amdgpu_top`, `vulkan-tools`, `lmstudio`, `podman` (the halogen model runs via podman inside llama-swap).

## Add / remove a model

1. Edit `llamaSwapConfig` in `hosts/halo/llm.nix`: the `models` attrset AND the `routing.router.settings.matrix` `vars`/`sets` (residency). Chat models also go in `chatModels` in `hosts/halo/openwebui.nix`.
2. Update `model_list` in root `litellm-config.yaml` to match — same `model_name`, and `max_input_tokens` = that model's llama-swap `capabilities.context`.
3. Rebuild halo (reloads llama-swap) and redeploy the docker LiteLLM container so it picks up the new `litellm-config.yaml`.
4. Container networking: the LiteLLM container runs on a separate machine and reaches halo's llama-swap over the LAN — `api_base` is `http://10.1.3.246:9292/v1` (halo's LAN IP, same as OMP uses). Git-pull `litellm-config.yaml` into the container and redeploy there. halo keeps `9292` open for this; nothing is opened on halo for LiteLLM itself.

## ajwa media stack

nixflix in `hosts/ajwa/media.nix`; every credential is a sops secret (see `docs/secrets.md`).
- **VPN:** only qBittorrent/SABnzbd run in the WireGuard namespace (kill switch). nixflix requires Prowlarr/Sonarr/Radarr all in or all out; they're out by choice.
- **qBittorrent login:** nixpkgs rewrites `qBittorrent.conf` on every start, so the WebUI hash is spliced in from sops `qbittorrent/password_hash` by an `ExecStartPre`. A password set in the WebUI won't survive a restart.
- **Seerr:** defining `seerr.radarr.<name>` / `seerr.sonarr.<name>` replaces nixflix's generated instance (option default, not merged) — restate `apiKey` and `isDefault`.
- **Maintainerr rules:** `nixflix.maintainerr.rules` is the source of truth. Groups are matched by `name`; unlisted groups are deleted and UI edits overwritten on each sync. Draft in the UI, export with `curl localhost:6246/api/rules`, port to Nix. Always set `arrAction` (option default is `DO_NOTHING`).
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
- Hard-coded LAN IP `10.1.3.246` appears in `home/mani/programs/omp.nix` (llama-swap base URL) and `home/mani/programs/ssh.nix` (halo Host) — update together if halo's address changes.
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

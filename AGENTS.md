# AGENTS.md

Coding-agent guide for this two-host Nix flake. Read before editing.

## Repo

Single flake, two hosts:
- `nightfury` — macOS (nix-darwin, `aarch64-darwin`), the daily driver.
- `halo` — **AI-only host**: NixOS (`x86_64-linux`), Framework Desktop, AMD AI Max 300 (Strix Halo). Runs all local LLM inference.

User `mani`, checkout `~/dotfiles`, remote `https://forgejo.internal.tismani.com/mani/dotfiles.git`.

## Layout

- `flake.nix` — the only place hosts are wired; two outputs: `darwinConfigurations.nightfury`, `nixosConfigurations.halo`.
- `hosts/nightfury/default.nix` — macOS host config.
- `hosts/halo/configuration.nix` — NixOS host entry; imports the halo modules below.
- `hosts/halo/llm.nix` — llama-swap + Lemonade/NPU stack (see AI stack).
- `hosts/halo/desktop.nix`, `hosts/halo/flatpak.nix`, `hosts/halo/power.nix` — host extras.
- `hosts/halo/hardware-configuration.nix` — generated per-machine; do not hand-edit.
- `modules/common/default.nix` — nix settings, GC, system packages (both hosts).
- `modules/common/stylix.nix` — Dracula theming.
- `modules/programs/fish.nix` — fish shell + aliases (both hosts).
- `home/mani/default.nix` — home-manager entry; imports the programs below.
- `home/mani/programs/` — per-program user config (omp, ssh, kitty, helix, herdr, starship, yt-dlp).
- `home/mani/desktop/` — niri + noctalia, Linux-only, imported per-host.
- `docs/` — per-host bootstrap plus `docs/halo-llm.md`, `docs/openwebui.md`.
- `litellm-config.yaml` — root; docker LiteLLM config (see AI stack).

## Halo AI stack

- **llama-swap = primary LLM runner.** NixOS systemd service `llama-swap`, listens `0.0.0.0:9292`, on-demand model swap. Model definitions live in `llamaSwapConfig` in `hosts/halo/llm.nix`.
- **LiteLLM = docker container on a SEPARATE machine (NOT Nix, NOT on halo).** Reads root `litellm-config.yaml` (git-pulled into the container), serves `:4000` on its own host, master key from container env `LITELLM_MASTER_KEY`. Reaches halo's llama-swap over the LAN at `10.1.3.246:9292`; no LiteLLM port is opened on halo.
- **Lemonade / lemond = NPU + TTS backend**, Nix-managed via `hardware.amd-npu` in `hosts/halo/llm.nix`, reachable `:13305`. Still present; no longer fronted by LiteLLM.
- **Open WebUI** — removed from Nix (was disabled).
- **OMP** (`home/mani/programs/omp.nix`, macOS-only) connects to **llama-swap directly** at `http://10.1.3.246:9292/v1`, not LiteLLM.
- Host GPU/ROCm tooling: `amdgpu_top`, `vulkan-tools`, `lmstudio`, `podman` (the halogen model runs via podman inside llama-swap).

## Add / remove a model

1. Edit `llamaSwapConfig` in `hosts/halo/llm.nix`: the `models` attrset AND the `routing.router` `large-gguf` group `members`.
2. Update `model_list` in root `litellm-config.yaml` to match — same `model_name`, and `max_input_tokens` = that model's llama-swap `capabilities.context`.
3. Rebuild halo (reloads llama-swap) and redeploy the docker LiteLLM container so it picks up the new `litellm-config.yaml`.
4. Container networking: the LiteLLM container runs on a separate machine and reaches halo's llama-swap over the LAN — `api_base` is `http://10.1.3.246:9292/v1` (halo's LAN IP, same as OMP uses). Git-pull `litellm-config.yaml` into the container and redeploy there. halo keeps `9292` open for this; nothing is opened on halo for LiteLLM itself.

## Build / verify / activate

- Verify WITHOUT activating:
  - nightfury: `nix build .#darwinConfigurations.nightfury.system`
  - halo: `nix build .#nixosConfigurations.halo.config.system.build.toplevel`
  - Shared-module edits (`modules/`, `home/`) → build both.
- NEVER run activation (`darwin-rebuild switch`, `nixos-rebuild switch`, or the fish `rebuild`/`rebuild-halo` aliases) unless explicitly asked — it mutates the live machine.
- Human workflow: fish `rebuild` (per-host switch, defined in `modules/programs/fish.nix`); `rebuild-halo` (macOS: rsyncs `~/dotfiles` to halo, then builds and switches on halo itself).
- `nix flake update` is NOT routine — keep the checked-in `flake.lock`.

## Conventions / landmines

- Do NOT change `system.stateVersion` (halo `"25.11"`, home `"24.11"`) or overwrite `hosts/halo/hardware-configuration.nix` (see `docs/halo-bootstrap.md`).
- Platform-conditional code uses `pkgs.stdenv.hostPlatform.isDarwin` (see `home/mani/programs/omp.nix`, `home/mani/programs/ssh.nix`, `modules/programs/fish.nix`); guard new OS-specific config the same way.
- Hard-coded LAN IP `10.1.3.246` appears in `home/mani/programs/omp.nix` (llama-swap base URL) and `home/mani/programs/ssh.nix` (halo Host) — update together if halo's address changes.
- SSH private keys are NOT in-repo (Bitwarden-managed; only `.pub` under `home/mani/programs/ssh.nix`). Never add private keys/tokens/secrets.
- Stylix themes everything Dracula; `home/mani/programs/herdr.nix` hand-matches it (no stylix herdr target) — keep in sync.
- `home/mani/default.nix` sets `home.homeDirectory` via `lib.mkDefault "/home/mani"`; nightfury overrides with `lib.mkForce "/Users/mani"`.
- Comments here explain WHY (workarounds / upstream quirks) — preserve that style.
- `flake.nix` intentionally pins `nix-amd-ai` outside nixpkgs `follows` (re-hash/rebuild reason in its comment) — don't "clean up".

## Where changes go

- New CLI tool for both hosts → `modules/common/default.nix` (system) or `home/mani/default.nix` (user).
- New shell program → new file in `home/mani/programs/` + add to `home/mani/programs/default.nix` imports.
- Host-specific → that host's `hosts/<name>/` module.

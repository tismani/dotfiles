# Nightfury: bootstrap after a fresh macOS install

This host is an Apple Silicon Mac (`aarch64-darwin`) with the macOS account
`mani`, home `/Users/mani`, and checkout `~/dotfiles`. The entry point is
[`hosts/nightfury/default.nix`](../hosts/nightfury/default.nix), selected by
`darwinConfigurations.nightfury` in [`flake.nix`](../flake.nix).
Home Manager runs as part of the system rebuild; no separate installation is needed.

## 1. Prepare macOS

1. Complete macOS Setup Assistant and create the administrator account `mani`.
   A different short username requires changing the system and Home Manager
   user definitions and hard-coded home paths in this repository.
2. Connect to the internet and install Command Line Tools from Terminal:

   ```sh
   xcode-select --install
   ```

   Finish the installer before continuing. Run these instructions in the default
   macOS zsh terminal, outside Rosetta; `uname -m` should print `arm64`.
3. Sign into the Mac App Store with the account that owns the configured apps.
   Resolve purchase/download prompts there, including paid apps, before rebuilding.

## 2. Install Nix using the Lix installer

On a Mac without Nix, use the [official Lix installer](https://lix.systems/install/):

```sh
curl -sSf -L https://install.lix.systems/lix | sh -s -- install
```

Follow its prompts, then open a new Terminal window and verify:

```sh
nix --version
```

Immediately after installation this should identify Lix. The repository does
**not** set `nix.package = pkgs.lix` or import a Lix module. The installer choice
is not preserved by the configuration: nix-darwin manages Nix and defaults to
upstream Nix on activation. This is documented in the
[nix-darwin prerequisites](https://github.com/nix-darwin/nix-darwin#prerequisites).
Keeping Lix permanently would require a separate configuration change.

## 3. Install Homebrew

The host manages Homebrew packages but does not install Homebrew itself. Use
the [Homebrew installer](https://brew.sh/), as `mani`:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew --prefix
```

The prefix must be `/opt/homebrew`. The host config adds that prefix to PATH
after activation. Homebrew activation updates/upgrades packages and uses
`cleanup = "zap"`, so review the host's `homebrew` list before bringing an
existing Homebrew installation under management.

## 4. Get this repository

```sh
git clone https://forgejo.internal.tismani.com/mani/dotfiles.git ~/dotfiles
cd ~/dotfiles
git status --short
```

The Forgejo URL requires working internal DNS/network access and repository
credentials. If it is unavailable before VPN setup, transfer a complete checkout
from a trusted backup or another machine, including `flake.lock` and `.git`, to
`~/dotfiles`. Do not put access tokens in the clone URL. Keep the checked-in lock
file for the initial install; do not run `nix flake update` as a bootstrap step.

## 5. Activate Nightfury

Use the [upstream nix-darwin bootstrap command](https://github.com/nix-darwin/nix-darwin#step-2-installing-nix-darwin),
selecting this repository's host explicitly:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake /Users/mani/dotfiles#nightfury
```

The bootstrap executable comes from upstream master; the target system uses
this repository's `flake.lock`. Activation installs the macOS defaults,
packages, Homebrew apps, and Home Manager configuration. Allow time for downloads
and respond to App Store or macOS installer prompts.

If activation reports an existing unmanaged file, back up the specific file it
names, move it aside, and retry. Do not delete entire shell/config directories.
Home Manager backs up conflicting managed files with `.backup`; an existing
backup may itself need moving aside. If an App Store download fails, resolve the
account or purchase prompt in the App Store and rerun the same command.

## 6. Finish the manual setup

1. Log out and back in to pick up system defaults and PATH changes. Launch apps
   and grant required macOS permissions (for example, Accessibility for keyboard
   utilities). Enroll Touch ID if you want the configured sudo authentication.
2. Open Bitwarden, sign in, unlock it, and enable its SSH agent. The SSH config
   expects the Mac App Store socket at
   `~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock`.
   Public keys are managed by Nix; their private keys must be restored in Bitwarden.
   Restore `~/.ssh/forgejo.key` and `~/.ssh/hermes.key` separately if needed, with
   mode `0600`; those keys are not in this repository.
3. Open Tailscale and sign in. If using NetBird, complete its service setup and
   enrollment too; installing its Homebrew formula does not enroll this Mac.
4. OMP's Halo provider uses `http://halo:4000/v1` and reads its Bearer token from
   `LITELLM_API_KEY`. Set it to the master key generated on Halo. Ensure `halo`
   resolves to a reachable LAN or Tailscale address; use Halo's LAN IP in
   `home/mani/programs/omp.nix` if needed. Follow
   [Halo LLM gateway setup](halo-llm.md) for manual Lemonade download and Nix
   registration steps. OMP uses `openai-models-list` discovery; its list stays
   empty until models are registered in Nix and Halo is rebuilt.
5. Terminal is configured to launch Fish, and its default/startup profiles use
   Kitty's shared terminal font size (currently 13 pt). Quit Terminal before a
   rebuild so its cached preferences do not overwrite the update, then reopen it.
   This sets Terminal's shell preference; the macOS account login shell remains
   unchanged. Run `fish` in other terminals when needed.

## 7. Verify and rebuild later

```sh
scutil --get HostName
nix --version
command -v darwin-rebuild
/opt/homebrew/bin/brew --prefix
sudo darwin-rebuild switch --flake ~/dotfiles#nightfury
```

The hostname should be `nightfury`. In Fish, `rebuild` applies the local host.
Once [Halo's bootstrap](halo-bootstrap.md) and SSH setup are complete, `ssh halo`
should work and `rebuild-halo` rsyncs the local `~/dotfiles` to Halo and
builds and activates it there. Its
address is currently hard-coded to `10.1.3.246` in
[`ssh.nix`](../home/mani/programs/ssh.nix); update it if Halo's address changes.

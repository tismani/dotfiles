# Halo: bootstrap after the NixOS GUI installer

This guide starts after installing NixOS with the graphical installer and booting
into the installed desktop. It adopts these dotfiles on Halo, the Framework
Desktop AMD AI Max (`x86_64-linux`), with GNOME and user `mani` at `/home/mani`.
The flake installs the system packages and Home Manager configuration together.
Nix is already installed; no separate Nix, Lix, or Home Manager installation is needed.

## 1. Check the fresh installation

In the GUI installer, use UEFI boot, choose GNOME, and create user `mani` with a
password and administrator access. The straightforward layout is an unencrypted
ext4 root and an EFI partition mounted at `/boot`; swap is optional. Let the
installer create the partitions. There are no required filesystem labels for
this walkthrough because you will use the hardware configuration it generated.
If installation is already complete, continue from your installed desktop.

Connect to the internet, open a terminal, and run these commands as your normal
user. Use Bash for the commands in this guide:

```sh
bash
whoami
printf '%s\n' "$HOME"
sudo -v
test -d /sys/firmware/efi && echo 'UEFI boot confirmed'
findmnt /
findmnt /boot
swapon --show
```

Expect `mani`, `/home/mani`, working sudo, UEFI confirmation, and the EFI
filesystem at `/boot`. An empty swap listing is fine if you selected no swap.
If you installed under another username, create a `mani` administrator account
in GNOME Settings and log into it before continuing. These dotfiles manage
`mani`; changing that identity requires editing the system and home configuration.

The host enables systemd-boot. If your install uses legacy BIOS, another EFI
mountpoint, or a different bootloader, adapt the host boot settings before
rebuilding. For an encrypted or custom filesystem layout, also carry over any
required storage/unlock settings from the installer configuration in step 4.
The host does not configure Secure Boot signing.

## 2. Back up the installer configuration

Save the working installation's configuration before adopting the flake:

```sh
INSTALL_BACKUP="$HOME/nixos-installer-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$INSTALL_BACKUP"
sudo cp -a /etc/nixos "$INSTALL_BACKUP/"
sudo chown -R "$(id -un):$(id -gn)" "$INSTALL_BACKUP"
printf 'Installer configuration saved to %s\n' "$INSTALL_BACKUP"
```

Keep this backup until the new system boots successfully. The original files in
`/etc/nixos` also remain in place; rebuilds with `--flake ~/dotfiles#halo` use the
checkout instead.

## 3. Get the dotfiles

Start a temporary shell with Git, then clone as `mani` so the checkout belongs
to your account:

```sh
nix-shell -p git
git clone https://forgejo.internal.tismani.com/mani/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
git status --short
```

Forgejo requires access to the internal network/DNS and repository credentials.
Arrange that connectivity first, or copy a complete checkout from another
machine or backup to `/home/mani/dotfiles`, including `.git` and `flake.lock`.
If that directory already contains your checkout, use it instead of cloning over
it. Keep the supplied lock file so the first build uses the pinned dependencies.

## 4. Use this installation's hardware configuration

The repository's
[`hosts/halo/hardware-configuration.nix`](../hosts/halo/hardware-configuration.nix)
currently expects labels `nixos`, `boot`, and `swap`. A GUI install may use UUIDs,
different labels, or no swap. Replace that file **in your Halo checkout** with the
one generated for the running installation:

```sh
cd "$HOME/dotfiles"
cp /etc/nixos/hardware-configuration.nix hosts/halo/hardware-configuration.nix
git diff -- hosts/halo/hardware-configuration.nix
cat /etc/nixos/configuration.nix
```

Check that the copied file describes your actual root, EFI mount, and swap (if
any). Preserve its UUIDs, filesystem types, mount options, and encryption settings.
Do not relabel or format the installed partitions to match the old file.
The Halo configuration already imports this file, and the flake separately
includes the Framework Desktop hardware module.

Review `/etc/nixos/configuration.nix` for installation-specific settings outside
the hardware file, especially `boot.initrd.luks`, keyfiles, additional mounts,
and bootloader settings. Transfer any required settings into
[`hosts/halo/configuration.nix`](../hosts/halo/configuration.nix), resolving
conflicting definitions before proceeding. Do not import the entire installer
configuration: it also defines settings already supplied by the flake.

For this fresh installation, set `system.stateVersion` in
`hosts/halo/configuration.nix` to the value from `/etc/nixos/configuration.nix`.
The repository currently says `25.11`; keep it if that matches the installer.
Keep `home.stateVersion = "24.11"` for the existing Home Manager configuration.
These are compatibility settings, not package-version selectors; do not bump
them as part of later updates. See the [NixOS manual](https://nixos.org/manual/nixos/stable/).

```sh
nano hosts/halo/configuration.nix
git diff --check
git diff -- hosts/halo/hardware-configuration.nix hosts/halo/configuration.nix
```

Edits to tracked files are included in a local flake build without a commit.
If you add new Nix files, run `git add` on those files so the Git-backed flake can
see them. Save the reviewed machine-specific changes in Git before future pulls
or remote rebuilds; every checkout used to deploy Halo needs the correct disk
configuration.

## 5. Build the Halo configuration

From the checkout, build without activating it:

```sh
sudo nixos-rebuild build --option experimental-features 'nix-command flakes' \
  --flake "$HOME/dotfiles#halo"
```

The explicit feature option allows this first command to work before the flake
has enabled flakes system-wide. The build includes the desktop, development
tools, and AMD GPU/NPU and LLM stack, so allow substantial time and free disk
space. If it fails, fix the reported error and rerun it before continuing.

## 6. Make it the next boot configuration and reboot

Once the build succeeds, install it as the next boot generation:

```sh
sudo nixos-rebuild boot --option experimental-features 'nix-command flakes' \
  --flake "$HOME/dotfiles#halo"
```

`boot` makes the new generation the default for the next startup; activation
happens on reboot. This lets the first kernel and desktop change take effect
together. See [nixos-rebuild](https://wiki.nixos.org/wiki/Nixos-rebuild).
Only after that command succeeds, save your work and reboot:

```sh
sudo reboot
```

Log into GNOME as `mani` using the password you set in the GUI installer. The
configuration supplies no replacement password, so the existing account password
is retained. The hostname is now `halo`; GNOME is enabled and Niri is disabled.

## 7. Verify the system and home configuration

Open a terminal and run:

```sh
hostname
findmnt /
findmnt /boot
swapon --show
systemctl --failed
systemctl status display-manager home-manager-mani flatpak-add-flathub --no-pager
ls -l ~/.ssh/halo.pub
flatpak list
```

Expect hostname `halo`, the same installed filesystems, and successful Home
Manager activation. The boot service installs Vivaldi and Bitwarden from Flathub.
If that download failed, restore connectivity and run:

```sh
sudo systemctl restart flatpak-add-flathub
```

If Home Manager fails, inspect its log:

```sh
journalctl -u home-manager-mani -b --no-pager
```

Home Manager backs up conflicting files with the `.backup` suffix. If an existing
backup blocks activation, move the specific conflicting file to your backup
folder, then rerun `sudo nixos-rebuild switch --flake ~/dotfiles#halo`.

Fish is installed but is not selected as the login shell. Run `fish` to use the
configured aliases. To make it your login shell, check that
`/run/current-system/sw/bin/fish` is listed in `/etc/shells`, then run:

```sh
chsh -s /run/current-system/sw/bin/fish
```

## 8. Restore network access and SSH

Enroll in Tailscale if you use it:

```sh
sudo tailscale up
```

For NetBird, run `sudo netbird up` if needed. Authentication and network
memberships are not stored in Nix. The managed `halo` SSH entry points to
`10.1.3.246`; restore that DHCP reservation or update
[`home/mani/programs/ssh.nix`](../home/mani/programs/ssh.nix) on your client and rebuild it.

SSH is enabled, but the configuration does not install authorized keys. To allow
the existing Bitwarden-held Halo identity to log in, run this once as `mani`:

```sh
install -d -m 0700 ~/.ssh
cat ~/.ssh/halo.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

On Nightfury, unlock Bitwarden and enable its SSH agent. After a reinstall,
compare the new host fingerprint shown locally above before replacing the old
client known-host entry. Then test `ssh halo` and `sudo -v` inside the session.

For outgoing SSH from Halo, open Bitwarden, sign in, and enable its SSH agent.
The configured socket is
`~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock`.
Restore disk-only private keys separately; the dotfiles supply only public keys.

## 9. Set up models when needed

```sh
systemctl status llama-swap --no-pager
curl --fail http://127.0.0.1:9292/v1/models
```

llama-swap serves `http://halo:9292/v1` without authentication. TCP port 9292 is
open on all interfaces, including the local network and Tailscale. No API key or
secret file is needed. The initial model list is empty; installation does not
download weights.

Follow [Halo LLM gateway setup](halo-llm.md) to download models with Lemonade,
register their absolute GGUF paths in `hosts/halo/llm.nix`, and rebuild.

## 10. Apply later changes and recover if needed

For routine changes:

```sh
cd ~/dotfiles
sudo nixos-rebuild switch --flake ~/dotfiles#halo
```

This applies both the system and Home Manager configuration. In Fish, `rebuild`
uses the local hostname to select Halo. Reboot after kernel changes.
Use the explicit flake command instead of a bare `nixos-rebuild switch`, which
would use the old installer configuration in `/etc/nixos`.

From a configured [Nightfury](nightfury-bootstrap.md), `rebuild-halo` builds and
activates on Halo over SSH and prompts for sudo authentication. It deploys the
Nightfury checkout, so first ensure that checkout includes Halo's saved hardware
and other configuration changes from this guide.

If the new generation cannot boot, select the previous working generation in
the systemd-boot menu (hold Space during startup to reveal it). From that system,
correct the checkout, rerun the `boot` command from step 6, and reboot. Keep the
installer USB and configuration backup available until the first successful
boot; if no generation boots, use the USB to repair the installed configuration.

# Halo: bootstrap after the NixOS GUI installer

This guide starts after installing NixOS with the graphical installer and booting
into the installed desktop. It adopts these dotfiles on Halo, the Framework
Desktop AMD AI Max (`x86_64-linux`), with GNOME and user `mani` at `/home/mani`.
The flake installs the system packages and Home Manager configuration together.
Nix is already installed; no separate Nix, Lix, or Home Manager installation is needed.

## 1. Check the fresh installation

In the GUI installer, use UEFI boot, choose GNOME, and create user `mani` with a
password and administrator access. Use an unencrypted ext4 root, a FAT32 EFI
system partition mounted at `/boot`, and a Linux swap **partition**. Choose a
swap-partition option in the installer, or use its manual partitioning screen
if necessary. The committed configuration requires all three; a swap file or
zram does not replace the swap partition for this setup.

The repository configuration is the source of truth. After installation, you
will change the filesystem labels to match it, keeping the committed hardware
configuration. If your fresh install uses encryption, Btrfs, a separate `/home`,
or no swap partition, it does not match this guide. For a disposable fresh
installation, rerun the GUI installer with the layout above before continuing;
back up any data you have added first.

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
filesystem at `/boot`, plus a Linux swap partition visible in `lsblk -f`.
If you installed under another username, create a `mani` administrator account
in GNOME Settings and log into it before continuing. These dotfiles manage
`mani`; changing that identity requires editing the system and home configuration.

The host enables systemd-boot and does not configure Secure Boot signing.
Use a UEFI installation with `/boot` as the EFI mountpoint and firmware settings
that permit this bootloader.

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

## 4. Label the installed partitions to match the config

Keep
[`hosts/halo/hardware-configuration.nix`](../hosts/halo/hardware-configuration.nix)
as committed. It requires these exact **filesystem labels**, which are different
from GPT partition names (`PARTLABEL`):

| Use | Filesystem | Exact label | Configured device |
| --- | --- | --- | --- |
| `/` | ext4 | `nixos` | `/dev/disk/by-label/nixos` |
| `/boot` | FAT32 (`vfat`) | `boot` | `/dev/disk/by-label/boot` |
| Swap | Linux swap partition | `swap` | `/dev/disk/by-label/swap` |

### Identify the devices

In the installed system, get the label tools and inspect the disks:

```sh
nix-shell -p e2fsprogs dosfstools util-linux
findmnt -no SOURCE,FSTYPE /
findmnt -no SOURCE,FSTYPE /boot
swapon --show
lsblk -o NAME,PATH,SIZE,MODEL,FSTYPE,LABEL,UUID,MOUNTPOINTS
cat /etc/nixos/hardware-configuration.nix
```

Match root and EFI to the mounted devices and identify the swap partition on the
same installed disk. Verify the model and size; do not select the installer USB
or another drive. Record the current UUIDs and labels in your backup folder.
Check all attached disks for duplicate `nixos`, `boot`, or `swap` labels; detach
any other disk with a conflicting label before continuing.

Set these variables to your verified partitions. The names below are examples;
the GUI installer may have created them in a different order:

```sh
ROOT_PART=/dev/nvme0n1p2
EFI_PART=/dev/nvme0n1p1
SWAP_PART=/dev/nvme0n1p3
sudo blkid "$ROOT_PART" "$EFI_PART" "$SWAP_PART"
```

Confirm those devices are respectively `ext4`, `vfat`, and `swap` before running
the next commands. Stop if any device or filesystem differs from that expectation.

### Change labels without formatting

The ext4 root label can be changed while mounted. Unmount the EFI filesystem
before changing its label, and deactivate the selected swap partition first.
Close applications before `swapoff`; if it fails because memory is insufficient,
stop and free memory before retrying. If the selected swap is already inactive,
skip the `swapoff` command.

Run each command separately and continue only when it succeeds. Keep the EFI
filesystem unmounted until its label has been set. If unmounting reports that it
is busy, close the process using `/boot` and retry; do not force the unmount.

```sh
sudo swapoff "$SWAP_PART"
sudo umount /boot
sudo "$(command -v e2label)" "$ROOT_PART" nixos
sudo "$(command -v fatlabel)" "$EFI_PART" boot
sudo "$(command -v swaplabel)" -L swap "$SWAP_PART"
sudo udevadm trigger --subsystem-match=block --action=change
sudo udevadm settle
sudo blkid "$ROOT_PART" "$EFI_PART" "$SWAP_PART"
ls -l /dev/disk/by-label/{nixos,boot,swap}
```

These commands change labels without recreating filesystems or changing UUIDs;
**do not run `mkfs` or `mkswap`**. Use lowercase `boot` even if `fatlabel` warns
that uppercase is preferred: the config requires that exact case. See the
[e2label manual](https://www.man7.org/linux/man-pages/man8/e2label.8.html),
[fatlabel manual](https://www.man7.org/linux/man-pages/man8/fatlabel.8.html), and
[swaplabel manual](https://www.man7.org/linux/man-pages/man8/swaplabel.8.html).

Verify that each `/dev/disk/by-label` link resolves to the intended partition and
that the UUIDs match those recorded earlier. Restore the EFI mount and swap using
the new labels:

```sh
sudo mount /dev/disk/by-label/boot /boot
sudo swapon /dev/disk/by-label/swap
findmnt /boot
swapon --show
```

Do not rebuild until `/boot` is mounted on the correct EFI partition and all
three labels resolve correctly.

If the installer configuration uses UUIDs, its previous boot generation remains
usable because the UUIDs have not changed. If it uses old labels, that generation
may no longer boot after relabeling; keep the installer USB available, and restore
the recorded old labels from the live USB if you need to recover that generation.
Do not reboot between relabeling and the successful `nixos-rebuild boot` in step 6.

### Keep the repository settings

Do not copy `/etc/nixos/hardware-configuration.nix` into the repository or replace
its label-based devices with installer UUIDs. Keep the committed
`system.stateVersion = "25.11"` and `home.stateVersion = "24.11"`; they are
compatibility settings for this configuration, not versions to bump on reinstall.
The Framework Desktop hardware module is already included by the flake.

```sh
cd "$HOME/dotfiles"
git diff -- hosts/halo/hardware-configuration.nix hosts/halo/configuration.nix
```

A fresh checkout should show no changes to these files. If you copied the
installer hardware file while following an earlier version of this guide,
restore the committed Halo file before building, preserving any unrelated work.

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

Expect hostname `halo`, root labeled `nixos`, EFI labeled `boot`, active swap
labeled `swap`, and successful Home Manager activation. Use `lsblk -f` to check
the labels. The boot service installs Vivaldi and Bitwarden from Flathub.
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

After connecting, verify normal LAN routing, DNS, and Tailscale:

```sh
ip route
getent hosts example.com
tailscale status
```

The managed `halo` SSH entry points to `10.1.3.246`; restore that DHCP
reservation or update
[`home/mani/programs/ssh.nix`](../home/mani/programs/ssh.nix) on your client and rebuild it.

SSH is enabled, but the configuration does not install authorized keys. To allow
the existing Bitwarden-held Halo identity to log in, run this once as `mani`:

```sh
install -d -m 0700 ~/.ssh
cat ~/.ssh/halo.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

OpenSSH accepts only the `mani` account; root and keyboard-interactive logins are
disabled. Password authentication remains enabled temporarily until an
authorized key has been confirmed. Connect with the normal OpenSSH client to
`mani` on port 22.

On Nightfury, unlock Bitwarden and enable its SSH agent. After a reinstall,
compare the new host fingerprint shown locally above before replacing the old
client known-host entry. Then test `ssh halo` and `sudo -v` inside the session.
Once the authorized key works, follow up by setting
`PasswordAuthentication = false`; preferably also restrict OpenSSH to the
overlay interfaces.

For outgoing SSH from Halo, open Bitwarden, sign in, and enable its SSH agent.
The configured socket is
`~/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock`.
Restore disk-only private keys separately; the dotfiles supply only public keys.

## 9. Set up models when needed

```sh
systemctl status llama-swap litellm --no-pager
sudo sed -n 's/^LITELLM_MASTER_KEY=//p' /var/lib/litellm/environment
```

LiteLLM serves the primary `http://halo:4000/v1` endpoint using a persistent
master key generated on first activation. Retrieve it locally with
`sudo sed -n 's/^LITELLM_MASTER_KEY=//p' /var/lib/litellm/environment`.
llama-swap remains directly available at `http://halo:9292/v1` as a fallback.
Both ports are open on all interfaces, including the local network and overlay
networks. The configured Qwen3.6, Qwen3.8, Nemotron, and Gemma GGUF models load
on demand; llama-swap keeps only one of them resident at a time.

Follow [Halo LLM gateway setup](halo-llm.md) for cache ownership, model paths,
and the post-deployment load and swap checks.

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
Nightfury checkout, so ensure it contains the intended configuration revision.
The committed filesystem labels work for both local and remote rebuilds.

If the new generation cannot boot, select the previous working generation in
the systemd-boot menu (hold Space during startup to reveal it). From that system,
inspect the failure and rerun the `boot` command from step 6 after fixing it.
Missing or incorrect labels must be corrected to match the committed config;
use the live USB if needed, with the installed filesystems unmounted and swap
inactive. Remember that an installer generation using old labels needs those
labels restored before it can boot. Keep the
installer USB and configuration backup available until the first successful
boot; if no generation boots, use the USB to repair the installed configuration.

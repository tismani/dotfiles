# Secrets (sops-nix)

Secrets live age-encrypted in `secrets/<host>.yaml`; `.sops.yaml` lists who can
decrypt each file. sops-nix decrypts them at activation into `/run/secrets`
(root 0400 by default). Never put a plaintext secret in a `.nix` file — Nix
copies it into the world-readable store.

## Keys

- **Admin (mani):** age key on nightfury at
  `~/Library/Application Support/sops/age/keys.txt` (sops' macOS default).
  Needed to edit any secret. Backed up in Bitwarden.
- **Hosts:** each NixOS host decrypts with its SSH host key
  (`/etc/ssh/ssh_host_ed25519_key`, set in `modules/common/sops.nix`). Its age
  recipient is derived from the public key — no extra key file on the host.

## First-time setup (nightfury)

```sh
mkdir -p ~/Library/Application\ Support/sops/age
age-keygen -o ~/Library/Application\ Support/sops/age/keys.txt
# Save the file in Bitwarden, then put the printed "Public key: age1…" into
# .sops.yaml as the &mani anchor.
```

## Add a host

```sh
ssh-keyscan -t ed25519 <host-ip> | ssh-to-age   # → age1…
```

Add it as an anchor under `keys:` in `.sops.yaml`, add a `creation_rules`
entry for `secrets/<host>.yaml`, and re-encrypt existing files for the new
recipient set with `sops updatekeys secrets/<host>.yaml`.

## Edit secrets

```sh
sops secrets/ajwa.yaml
```

Keys are nested YAML; `sops.secrets."sonarr/api_key"` reads `sonarr: api_key:`.
Generate *arr API keys with `openssl rand -hex 16`.

## ajwa (nixflix) secret keys

Declared in `hosts/ajwa/media.nix`; every one must exist in `secrets/ajwa.yaml`
or activation fails:

```yaml
prowlarr: { api_key: …, username: …, password: … }
sonarr:   { api_key: …, username: …, password: … }
radarr:   { api_key: …, username: …, password: … }
jellyfin: { api_key: …, admin_password: … }
qbittorrent: { username: …, password: …, password_hash: … }
sabnzbd:  { api_key: …, nzb_key: … }
seerr:    { api_key: … }
usenet:
  newshosting: { username: …, password: … }
indexers:          # one per Prowlarr indexer that needs credentials
  ninjacentral: { api_key: … }
wireguard:
  conf: |          # whole wg-quick .conf, indented under `|`
    [Interface]
    ...
```

Adding a Prowlarr indexer with credentials takes both an `indexers/<name>/…`
key here and a matching `sops.secrets."indexers/<name>/…" = { };` in
`media.nix`, or activation fails.

qBittorrent's WebUI login comes from `qbittorrent/password_hash`, spliced into
its config at each start (nixpkgs overwrites qBittorrent.conf, so a password
set in the WebUI doesn't survive a restart). Generate it from the same value
as `qbittorrent/password`:

```sh
nix run git+https://codeberg.org/feathecutie/qbittorrent_password -- --password '<password>'
```

# herdr quick start

Config lives in `home/mani/programs/herdr.nix` and is rendered to
`~/.config/herdr/config.toml`. Never edit that file directly — it is a
read-only symlink into the nix store.

## Mental model

herdr nests three levels, plus a sidebar:

```
workspace (aka "space")   ← roughly a tmux session; has a cwd + git branch
└── tab                   ← roughly a tmux window
    └── pane              ← same as tmux
```

The **sidebar** on the left is the part tmux has no equivalent for. It lists
every workspace and every detected coding agent with a live state icon:
working / blocked / idle / done. That is the whole reason herdr exists — you
can see at a glance which agent is sitting there waiting on you.

herdr runs a **background server**. Closing the terminal, or the laptop lid,
does not kill anything. `resurrect` + `continuum` are not needed.

## Keys

Prefix is `ctrl+a`, same as the old tmux config. Press prefix, release, then
the key.

| Key | Action |
| --- | --- |
| `prefix ?` | help — the built-in cheatsheet, start here |
| `prefix s` | settings UI |
| `prefix d` | detach (server keeps running) |
| `prefix b` | toggle the sidebar |

### Panes

| Key | Action |
| --- | --- |
| `prefix \|` | split side-by-side |
| `prefix -` | split stacked |
| `prefix h/j/k/l` | focus pane left/down/up/right |
| `prefix tab` | cycle panes |
| `prefix a` | last pane |
| `prefix m` or `prefix z` | zoom / unzoom |
| `prefix r` | resize mode — then h/j/k/l to resize, esc to exit |
| `prefix x` | close pane |

### Tabs

| Key | Action |
| --- | --- |
| `prefix c` | new tab |
| `prefix n` / `prefix p` | next / previous tab |
| `prefix 1`…`9` | jump to tab |
| `prefix shift+t` | rename tab |
| `prefix shift+x` | close tab |

### Workspaces

| Key | Action |
| --- | --- |
| `prefix w` | workspace picker |
| `prefix g` | goto — fuzzy jump to any workspace/tab/pane |
| `prefix shift+n` | new workspace |
| `prefix shift+g` | new git worktree as a workspace |
| `prefix shift+w` | rename workspace |
| `prefix shift+d` | close workspace |

### Scrollback

| Key | Action |
| --- | --- |
| `prefix [` | copy mode (vi keys, `v` select, `y` yank) |
| `prefix e` | open scrollback in `$EDITOR` |

Mouse is on: drag selects and copies, wheel scrolls.

## CLI

```sh
herdr                        # launch or attach to the persistent session
herdr status                 # client + server status
herdr --session work         # named session, separate from the default
herdr session attach work
herdr --remote halo          # attach to a herdr server over SSH
herdr server reload-config   # after a rebuild, no restart needed
herdr server stop
herdr config check           # validate config.toml, prints what it ignored
```

`herdr api ...`, `herdr workspace ...`, `herdr pane ...` drive the socket API —
that is what lets an agent open its own panes.

## Coming from the old tmux config

| tmux | herdr |
| --- | --- |
| `prefix \|` / `prefix -` | same |
| `prefix h/j/k/l` resize | `prefix r` then h/j/k/l |
| `prefix m` zoom | same |
| copy mode `v` / `y` | same, entered with `prefix [` |
| `resurrect` + `continuum` | built in, nothing to configure |
| dracula status bar | the sidebar, themed `dracula` |
| `prefix M-c` re-root session | `new_cwd = "follow"` does this per pane |

**What was lost:** `vim-tmux-navigator`. herdr has no vim-awareness, so bare
`ctrl+h/j/k/l` cannot be shared between herdr and Helix — a bare binding would
be swallowed before Helix ever saw it. Pane navigation therefore stays on the
prefix (`prefix h/j/k/l`). Inside Helix, use Helix's own window keys.

## Applying changes

```sh
# nightfury
sudo darwin-rebuild switch --flake ~/dotfiles

# halo
sudo nixos-rebuild switch --flake ~/dotfiles
```

Then `herdr server reload-config` (or `prefix shift+r`) to pick up config
changes without dropping panes.

## Notes

- The theme is set by hand because stylix has no herdr target. If the base16
  scheme in `modules/common/stylix.nix` ever changes, update
  `theme.name` in `herdr.nix` to match. Built-ins: `catppuccin`, `dracula`,
  `tokyo-night`, `nord`, `gruvbox`, `one-dark`, `solarized`, `kanagawa`,
  `rose-pine`, `vesper`, plus `-light`/`-latte`/`-dawn` variants.
- `theme.custom.panel_bg = "reset"` keeps stylix's `opacity.terminal = 0.9`
  visible through herdr's panels instead of painting them opaque.
- herdr's own updater is disabled (`update.version_check = false`); nixpkgs
  owns the version. Bump it with `nix flake update nixpkgs`.
- `herdr config check` reports unknown keys and invalid bindings but does *not*
  validate theme names — a typo there silently falls back.

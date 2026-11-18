# Ember

NixOS configuration for wallyhao's laptop: Niri, Waybar, Fuzzel, Mako, Foot,
Fcitx5/Rime, and a separately managed CLI/oh-my-pi/Zen Browser user profile. Emberlight is the
single Stylix colour source. The five desktop appearance components follow the
current Folio layout and geometry, with Emberlight colours.

## Identity

- Target: `nixosConfigurations.ember`, hostname `ember`, x86_64-linux.
- User: `wallyhao`, UID 1000, `/home/wallyhao`. Existing passwords/stateVersion stay.
- greetd/tuigreet password login, rescue tty2, GNOME Keyring/PAM preserved.
- Existing internal-disk layout and HEARTH_* labels are deliberately unchanged.
- Noctalia is no longer configured. Old private data is retained for rollback.
- `nixosConfigurations.hearth` is a temporary compatibility alias; the system
  built by either flake output is Ember.

## Daily commands

Run inside the persistent Ember repository, without prefixing just with sudo:

```sh
just          # list the commands
just apps     # user software: install (default), list, history, rollback, build
just vpn      # Mihomo: status (default), on, off, check, import a provider file
just check    # lints, CLI tests, path/secret scans, flake evaluation
just build    # build the system-preview toplevel (never installs or activates)
just vm       # VM checks: all of them, or one selected from the menu
just format   # rewrite .nix files with nixfmt
```

No command takes positional arguments; the actions that need input (`import` a
provider file, `rollback` to a generation) prompt for it.

Select applications in `software/selection/user-packages.nix`, then run `just apps`
(install is the default menu choice). Native profile state remains
`~/.local/state/nix/profiles/profile`; the old cached Hearth bundle and old
local flake origin have bounded migration compatibility.

## Gaming

The gaming stack is opt-in and currently off: `hosts/ember/default.nix` sets
`ember.gaming.enable = false`. When enabled, Steam, GE-Proton, GameMode,
Gamescope, MangoHud, `xwayland-satellite`, and the `nvidia-offload` wrapper are
system components owned by `modules/gaming.nix`.
The Steam library lives on `/persist`. Hybrid-GPU launch options, Proton
choices, VRR, and the compatibility limits are documented in
[the gaming notes](docs/gaming.md). Use `nvidia-offload steam` for a whole
session; the guide has the per-game offload launch option.

## Development toolchains

Python and JavaScript/TypeScript are owned by their language package managers;
Nix only supplies the runtime and the manager. Both are declared in
`software/package-set.nix` (`devNames`), so `just apps` installs and upgrades
them and no manual `nix profile install` is needed.

| Language | From Nix | Project dependencies |
| --- | --- | --- |
| Python | `uv` | `pyproject.toml` + `uv.lock`; interpreters via `uv python install` |
| JS/TS | `nodejs_24`, `pnpm` | `package.json` + `pnpm-lock.yaml` |

`uv` owns Python for project work: `uv run`, `uv tool install`, and
`uv python install` are the only entry points. `programs.nix-ld` is enabled so
the uv-downloaded CPython build can start on NixOS. The `python3` in the Ember
devShell exists solely for `scripts/ember`; it is not part of the user
environment. uv interpreters/tools/cache and the pnpm store are preserved under
`/persist` by `users/wallyhao/persistence.nix`. C/C++ tooling is intentionally
not installed.

OMP discovers skills as `~/Documents/skills/<name>/SKILL.md`;
`modules/programs/omp.nix` registers that root on every Home Manager activation
without dropping other custom roots. Discovery runs at OMP startup, so a newly
added skill appears in the next session.

## Migrating private source data

`./scripts/ember migrate-folio-data` runs on Folio with the reviewed internal
filesystems mounted below `/mnt`. It requests local sudo, extracts
nodes/subscriptions and copies saved NM connections to protected target state.
It does not copy Folio routing/DNS policy or change Folio services. Never paste
private sources in chat.

## Deployment status

The source is buildable and the desktop has been exercised in VMs; the host has
not been installed or activated, and the private Folio data has not been copied
yet.

## Documentation

- [architecture](docs/architecture.md): module layering, evaluation chain, flake outputs, state model.
- [operations](docs/operations.md): login, boot menu, network and proxy, desktop session, storage, maintenance.
- [gaming](docs/gaming.md): optional Steam/Proton stack and hybrid graphics.
- [hardware](docs/hardware.md): observed devices, PRIME bus IDs, nixos-facter report.
- [deployment](docs/deployment.md): private-data copy and installing onto the internal disk.

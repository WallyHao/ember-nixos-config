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
- `nixosConfigurations.hearth` and `scripts/hearth` are temporary compatibility
  aliases; the system built by either flake output is Ember.

## Daily commands

Run inside the persistent Ember repository, without prefixing just with sudo:

```sh
just proxy status
just proxy on
just proxy off
just proxy import ~/Downloads/provider.yaml
just profile install
just profile list
just profile history
just profile rollback
```

Select applications in `software/user-packages.nix`, then `just profile install`.
Native profile state remains `~/.local/state/nix/profiles/profile`; the old cached
Hearth bundle and old local flake origin have bounded migration compatibility.

## Migrating private source data

`just migrate-folio-data` runs on Folio with the reviewed internal filesystems
mounted below `/mnt`. It requests local sudo, extracts nodes/subscriptions and
copies saved NM connections to protected target state. It does not copy Folio
routing/DNS policy or change Folio services. Never paste private sources in chat.
See [migration instructions](docs/phase4-migration.md).

## Migration status

The source migration and final system build are complete. Targeted validation is
recorded separately from pending private data transfer and physical deployment.
See [deployment instructions](docs/phase4-deployment.md).
See [status](docs/phase4-status.md) and [implementation report](docs/phase4-report.md).

Historical phase1/2/3 documents describe their original generations. They do not
mean the new desktop has already passed those tests or is already installed.

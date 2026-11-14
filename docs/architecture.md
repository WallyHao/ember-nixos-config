# Architecture

This document describes the current Ember configuration. Ember has one host
(`ember`) and one normal user (`wallyhao`); the same assembly is used for the
real host, `system-preview`, and the VM checks.

## Layering

```text
inventory/
  default.nix              host/user data and module paths
  schema.nix               structural validation and storage gate

lib/
  eval-inventory.nix       validates and evaluates inventory
  mk-host.nix              the system assembly function
  deployment.nix           serializable deployment state

hosts/laptop/
  default.nix              host policy; imports the laptop suite
  hardware.nix             Intel/NVIDIA, initrd modules, firmware
  power.nix                TLP parameters
  storage-spec.nix         target disk, layout module, confirmation
  storage.nix              binds storage-spec to the layout
  storage-layout.nix       disko partitions, Btrfs subvolumes, tmpfs root

suites/nixos/
  base.nix                 capability modules
  desktop.nix              system desktop modules + Home Manager bridge
  laptop.nix               base + desktop, TTY-only host policy

modules/nixos/
  default.nix              capability module root
  identity.nix             ember.* identity into NixOS settings
  accounts.nix             userborn, users, groups, passwords
  boot.nix                 boot loader, initrd, getty
  network.nix              NetworkManager, resolved, firewall
  proxy.nix                Mihomo TUN proxy and helper CLI
  power.nix                TLP ownership and power policy
  memory.nix               zram, swap policy, Nix parallelism
  persistence.nix          preservation mounts and early boot ordering
  platform.nix             platform integration
  home-manager.nix         system identity -> Home Manager user
  foundation/              Nix, locale, maintenance, package policy
  appearance/              Stylix, login, newt
  desktop/                 session, security, audio, portals, input method

modules/home/
  default.nix              user environment root and desktop bridge options
  appearance/              Emberlight adapters
  desktop/                 Niri, Waybar, Fuzzel, Mako, clipboard, Zen, lock
  terminal/                Foot, Zsh, terminal tools
  editor/                  NixVim
  tools/                   OMP, btop, Yazi
  shared/                  profile/session integration

users/wallyhao/
  home.nix                 imports modules/home and user preferences
  preferences.nix          user preferences
  persistence.nix          user persistent directories
  bootstrap-password.nix   initial account hash

software/
  flake.nix                independent nixpkgs pin for the user profile
  packages.nix             base / workstation package sets
  user-packages.nix        additional application selection
  policy.nix               explicit unfree allowlist
  omp.nix, zen.nix         local package definitions

tests/
  eval/                    Nix evaluation contracts
  vm/                      QEMU VM tests
  fixtures/                virtual hardware and virtual storage
```

## Evaluation chain

`flake.nix` imports `flake/hosts.nix`, `flake/modules.nix`,
`flake/checks.nix`, and `flake/development.nix` through flake-parts.

The real system is assembled as:

```text
inventory.hosts.ember
  ├─ system, hostName, stateVersion
  ├─ physicalHardwareModule
  ├─ hostModule = hosts/laptop
  ├─ users = [ "wallyhao" ]
  └─ storage = hosts/laptop/storage-spec.nix

inventory.users.wallyhao
  ├─ uid, home, login shell, groups
  ├─ initialHashedPassword
  ├─ homeModule = users/wallyhao/home.nix
  ├─ persistenceModule = users/wallyhao/persistence.nix
  └─ homeStateVersion
```

`lib/mk-host.nix` evaluates that data and builds a `nixosSystem` with these
modules:

```text
preservation.nixosModules.preservation
stylix.nixosModules.stylix
modules/nixos/default.nix
host.hostModule
hardwareModule
identityModule
modules/nixos/home-manager.nix
home-manager.nixosModules.home-manager
users/wallyhao/persistence.nix
disko.nixosModules.disko + storageModule   (only when storage is passed)
```

`identityModule` is generated in `mk-host.nix`; it supplies `ember.hostName`,
`ember.stateVersion`, user identity, home module, and Home Manager state
version. `modules/nixos/identity.nix` maps the system fields, while
`modules/nixos/home-manager.nix` creates:

```text
home-manager.users.wallyhao
  ├─ imports = [ users/wallyhao/home.nix ]
  ├─ home.username
  ├─ home.homeDirectory
  └─ home.stateVersion
```

`users/wallyhao/home.nix` imports `modules/home` and `preferences.nix`.
`modules/home/default.nix` bridges `osConfig.ember.desktop.enable` into the
user session and imports the Niri, desktop, terminal, editor, and tool modules.

## Host path

The current host directory is still named `hosts/laptop`. Its actual chain is:

```text
inventory.hosts.ember.hostModule
  -> hosts/laptop/default.nix
     -> suites/nixos/laptop.nix
        -> suites/nixos/base.nix
           -> modules/nixos/default.nix
        -> suites/nixos/desktop.nix
           -> modules/nixos/desktop
           -> modules/nixos/home-manager.nix
     -> hosts/laptop/power.nix
```

`hosts/laptop/hardware.nix`, `storage-spec.nix`, `storage.nix`, and
`storage-layout.nix` are passed separately by `mk-host.nix`.

## System and user ownership

System modules own boot, accounts, networking, proxy, power, persistence,
login, portals, audio, and the system Stylix configuration.

Home Manager modules own the user Niri configuration, Waybar, Fuzzel, Mako,
Foot, Fcitx5, clipboard, lock/idle services, Zen, NixVim, and user tools.
They read the Emberlight palette through `config.ember.appearance`, which is
derived from Stylix; no adapter reads the JSON asset directly.

The user software profile is separate from both layers:

```text
software/flake.nix
  -> packages.x86_64-linux.workstation
       -> base CLI + OMP + software/user-packages.nix
```

It has its own `software/flake.lock`. `just profile install` manages
`~/.local/state/nix/profiles/profile`; NixOS and Home Manager do not install
that profile.

## State model

The root filesystem is tmpfs. Storage provides separate `/nix`, `/persist`,
and ESP filesystems. `preservation` binds persistent state from `/persist`
back into the tmpfs root, including:

```text
/persist/var/lib/nixos
/persist/var/lib/userborn
/persist/var/lib/bluetooth
/persist/var/lib/tlp
/persist/var/lib/systemd/{timers,random-seed}
/persist/var/log/journal
/persist/etc/NetworkManager/system-connections
/persist/etc/machine-id
/persist/home/wallyhao/Workspace
/persist/home/wallyhao/Documents
/persist/home/wallyhao/Downloads
/persist/home/wallyhao/Pictures
/persist/home/wallyhao/.local/state/nix
```

User-specific directories are listed in `users/wallyhao/persistence.nix`.
The user password database is under `/var/lib/nixos`; userborn runs after the
preservation early mounts.

## Flake outputs

| Output | Current behavior |
| --- | --- |
| `nixosConfigurations.ember` | real host; only when `deployment.installable` |
| `nixosConfigurations.hearth` | compatibility alias for `ember` |
| `nixosModules.default` | preservation + capability modules |
| `nixosModules.emberLaptop` | portable host modules without storage |
| `nixosModules.hearthLaptop` | compatibility alias |
| `lib.ember.deployment` | serializable deployment state |
| `lib.hearth.deployment` | compatibility alias |
| `packages.x86_64-linux.system-preview` | real hardware + fixture storage |
| `checks.x86_64-linux.desktop-config` | Niri/Foot/NixVim config checks |
| `checks.x86_64-linux.eval-contracts` | system and negative-case contracts |
| `checks.x86_64-linux.eval-user-environment` | Home Manager contracts |
| `checks.x86_64-linux.vm-*` | account, persistence, boot, desktop, network |

## Deployment gate

`lib/deployment.nix` derives `storageBound` from:

```text
targetDisk != null
layoutModule != null
layoutConfirmed == true
```

`nixosConfigurations.ember` is exported only when that condition holds.
`system-preview` always uses `tests/fixtures/storage.nix` and never selects the
real disk. VM tests use the fixtures under `tests/fixtures/`; no fixture value
is written into `hosts/laptop/storage-spec.nix`.

## Checks and fixtures

`system-preview` combines the real hardware module with virtual storage.
`tests/fixtures/hardware.nix` disables physical-only behavior where necessary.
The VM checks cover accounts, persistence, offline boot, offline desktop,
desktop interaction, user environment, and connectivity.

`flake/checks.nix` also exposes `desktop-config`, `eval-contracts`, and
`eval-user-environment`. The real host output is not activated by any check.

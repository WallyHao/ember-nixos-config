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

hosts/ember/
  default.nix              host policy; imports the laptop suite
  hardware.nix             Intel/NVIDIA, initrd modules, firmware
  power.nix                host-specific TLP parameters
  storage-spec.nix         target disk, layout module, confirmation
  storage.nix              binds storage-spec to the layout
  storage-layout.nix       disko partitions, Btrfs subvolumes, tmpfs root

suites/nixos/
  base.nix                 system, network, power, appearance
  desktop.nix              graphical session + Home Manager bridge
  laptop.nix               base + desktop, TTY-only host policy

modules/
  system/                  identity, accounts, boot, platform, foundation,
                           memory, persistence
  network/                 NetworkManager, resolved, firewall, Mihomo proxy
  power.nix                TLP and power policy
  session/                 graphical session, PAM, portals, audio,
                           system input method
  appearance/              Stylix, login, TTY appearance and assets
  desktop/                 Home Manager desktop options, theme, Waybar,
                           Fuzzel, Mako, clipboard, lock, cursor
  niri/                    Niri configuration, actions, bindings,
                           single-window service and script
  terminal/                Foot, Zsh, terminal tools and p10k
  apps/                    NixVim and profile PATH/desktop integration
  profile/                 configuration for profile-installed applications

users/wallyhao/
  home.nix                 imports desktop, niri, terminal, apps, profile
  preferences.nix          user preferences
  persistence.nix          user persistent directories
  bootstrap-password.nix   initial account hash

software/
  flake.nix                independent nixpkgs pin for the user profile
  package-set.nix          individually exposed user-profile packages
  policy.nix               explicit unfree allowlist
  packages/                profile-specific package recipes
    omp.nix
    zen.nix
  selection/
    user-packages.nix      additional application selection
  bootstrap/
    packages               per-package store paths for first install
    fingerprint            declaration/cache consistency check
    legacy-workstations.json

tests/
  eval/                    Nix evaluation contracts
  vm/                      QEMU VM tests
  fixtures/                virtual hardware and virtual storage
```

Only `modules/` has public modules. A complex module is a directory with one
`default.nix` entry point; a simple module is one `.nix` file. Consumers import
the directory, not its internal files. Resources live with the module that owns
them.

## Evaluation chain

`flake.nix` imports `flake/hosts.nix`, `flake/modules.nix`,
`flake/checks.nix`, and `flake/development.nix` through flake-parts.

The real system is assembled as:

```text
inventory.hosts.ember
  ├─ system, hostName, stateVersion
  ├─ physicalHardwareModule
  ├─ hostModule = hosts/ember
  ├─ users = [ "wallyhao" ]
  └─ storage = hosts/ember/storage-spec.nix

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
modules/system/default.nix
host.hostModule
hardwareModule
identityModule
modules/system/home-manager.nix
home-manager.nixosModules.home-manager
users/wallyhao/persistence.nix
disko.nixosModules.disko + storageModule   (only when storage is passed)
```

`identityModule` is generated in `mk-host.nix`; it supplies `ember.hostName`,
`ember.stateVersion`, user identity, home module, and Home Manager state
version. `modules/system/identity.nix` maps the system fields, while
`modules/system/home-manager.nix` creates:

```text
home-manager.users.wallyhao
  ├─ imports = [ users/wallyhao/home.nix ]
  ├─ home.username
  ├─ home.homeDirectory
  └─ home.stateVersion
```

`users/wallyhao/home.nix` imports the public Home Manager modules directly.
`modules/desktop/default.nix` owns the `ember.desktop` Home Manager options and
imports the desktop components. `modules/system/home-manager.nix` bridges the
same identity into Home Manager.

## Host path

```text
inventory.hosts.ember.hostModule
  -> hosts/ember/default.nix
     -> suites/nixos/laptop.nix
        -> suites/nixos/base.nix
           -> modules/system
           -> modules/network
           -> modules/power.nix
           -> modules/appearance
        -> suites/nixos/desktop.nix
           -> modules/session
           -> modules/system/home-manager.nix
     -> hosts/ember/power.nix
```

`hosts/ember/hardware.nix`, `storage-spec.nix`, `storage.nix`, and
`storage-layout.nix` are passed separately by `mk-host.nix`.

## System and user ownership

System modules own boot, accounts, networking, proxy, power, persistence,
login, portals, audio, and the system Stylix configuration.

Home Manager modules own the user Niri configuration, Waybar, Fuzzel, Mako,
Foot, Fcitx5, clipboard, lock/idle services, NixVim, and user tools. They read
the Emberlight palette through `config.ember.appearance`, which is derived from
Stylix; no adapter reads the JSON asset directly.

`modules/profile/` contains configuration for applications installed by the
separate software profile. It has no package download or installation logic.

The user software profile is separate from both layers:

```text
software/flake.nix
  -> packages.x86_64-linux.<name>
       -> one profile entry per declared package
       -> bootstrap/packages provides the matching offline closure paths
```

It has its own `software/flake.lock`. `just profile install` manages
`~/.local/state/nix/profiles/profile`; NixOS and Home Manager do not install
that profile. The script only reconciles entries owned by the Ember software
flake and preserves manually installed entries.

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
is written into `hosts/ember/storage-spec.nix`.

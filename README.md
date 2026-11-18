# Ember

Ember is my personal NixOS and Home Manager configuration for one laptop: a Lenovo
Legion Y7000 IRX9 running [Niri] on Wayland. It binds real hardware, storage and
account data, so it is **not a general-purpose template**. Read it as a reference and
take the parts that fit your own machine.

- **System** — `nixosConfigurations.ember`, hostname `ember`, `stateVersion = "26.11"`.
  A tmpfs root, Btrfs `@nix` / `@persist` subvolumes, `disko` for the layout and
  `preservation` for state that must survive reboots.
- **Desktop** — Niri with Waybar, Fuzzel, Mako, Foot and Fcitx5/Rime. Stylix resolves
  the Emberlight palette; every managed component reads that one source.
- **User software** — an independently locked Nix profile for CLI tools, OMP and Zen
  Browser. Updating it does not rebuild the system or Home Manager.

## Architecture

| Path | Responsibility |
| --- | --- |
| `inventory/` | Host, user, storage and module paths, with structural validation |
| `hosts/ember/` | Hardware, power, storage declaration and host policy |
| `suites/nixos/` | Base, desktop and laptop compositions |
| `modules/` | System, network, session, appearance, desktop, Niri, terminal, NixVim and program modules |
| `users/wallyhao/` | Home Manager entry, preferences and persistence whitelist |
| `software/` | Separate flake and lock for the user profile |
| `tests/` | Evaluation contracts, fixtures and QEMU VM checks |

`lib/mk-host.nix` assembles the same modules for the real host, `system-preview` and
the VM tests. `nixosConfigurations.ember` is exported only when the target disk,
layout module and confirmation are all present; otherwise only the portable
`nixosModules.emberLaptop` and preview outputs exist.

## Desktop

| Area | Choice |
| --- | --- |
| Session | greetd + tuigreet, `niri-session`, password-protected tty2 rescue |
| Bar, launcher, notifications | Waybar, Fuzzel, Mako |
| Terminal and shell | Foot, Zsh, p10k, tmux, Atuin (local history only) |
| Editor | NixVim with LSP servers and managed themes |
| Input method | Fcitx5 + Rime, configured by the system session |
| Browser and AI tools | Zen Browser and OMP, installed by the user profile |
| Files and images | Yazi, udiskie auto-mount, imv, Satty screenshots |
| Network | NetworkManager + systemd-resolved, Mihomo proxy, `file-drop` |
| Audio | PipeWire and WirePlumber |
| Lock and idle | swaylock, swayidle and the `ember-lock` user service |

The gaming stack (Steam, GE-Proton, GameMode, Gamescope, MangoHud and the NVIDIA
offload wrapper) is opt-in and currently off in `hosts/ember/default.nix`.

## Theme

Emberlight is a dark Base16 scheme defined once in
[`assets/themes/emberlight.json`](assets/themes/emberlight.json). Stylix normalises it,
and Waybar, Fuzzel, Mako, Foot, NixVim, swaylock and GTK derive their colours from the
resolved palette. Fonts are LXGW WenKai Mono GB at size 18.

## Daily commands

Run these inside the repository as `wallyhao`; no command takes positional arguments.

| Command | Purpose |
| --- | --- |
| `just` | List the available commands |
| `just check` | Format, lint, path/secret scans, CLI tests and flake evaluation |
| `just build` | Build the `system-preview` toplevel; never installs or activates |
| `just vm` | Build all VM checks, or one selected from the menu |
| `just format` | Rewrite `.nix` files with nixfmt |
| `just apps` | Install, list, roll back or build the declared user software |
| `just vpn` | Mihomo status, on/off, node selection and provider import |

`scripts/ember` provides the non-interactive backend used by the menu and tests. The
user profile lives at `~/.local/state/nix/profiles/profile`; edit
[`software/selection/user-packages.nix`](software/selection/user-packages.nix) and run
`just apps` instead of calling `nix profile install` by hand.

## Deployment

The configuration has been built and exercised in VMs, but it has **not** been
installed or activated on the host yet. `system-preview` uses fixture storage and never
selects the internal disk. Proxy subscriptions, saved network connections and other
private runtime data are not part of this repository.

Do not deploy this flake directly onto another machine. Start from `inventory/`,
`hosts/ember/storage-spec.nix`, `hosts/ember/hardware.nix` and the account setup, then
follow [`docs/deployment.md`](docs/deployment.md).

## Checks

`just check` runs nixfmt, deadnix, actionlint, ShellCheck, the CLI suite, repository
scans and flake evaluation. CI repeats those checks and builds the system preview plus
the storage, desktop and refresh checks on every push. The VM suite covers accounts,
persistence, offline boot, desktop, user environment, connectivity and `file-drop`; it
runs on manual dispatch.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) — layering, evaluation chain, outputs and state model.
- [`docs/operations.md`](docs/operations.md) — login, boot menu, network, proxy, session and storage.
- [`docs/hardware.md`](docs/hardware.md) — observed devices, PRIME bus IDs and disk layout.
- [`docs/deployment.md`](docs/deployment.md) — private-data copy and installation.
- [`docs/gaming.md`](docs/gaming.md) — optional Steam/Proton stack and hybrid graphics.
- [`modules/README.md`](modules/README.md), [`software/README.md`](software/README.md) — module and profile conventions.

[Niri]: https://github.com/YaLTeR/niri

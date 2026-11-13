# Phase 2 decisions

Date: 2026-11-09. Status: implementation evidence is filled in `phase2-report.md`.

## Locked inputs

| Input | Locked revision | Role |
| --- | --- | --- |
| root nixpkgs | `f4a03c008967841f2a0b3cb7c436fc6fc31671f6` | Existing system, Niri, Foot, Noctalia package, fonts, PAM |
| disko | `cedd626e11b635470fa6f9fdb8ad79b0075dd7f9` | Existing virtual disk tests |
| preservation | `00be7f7dd1a11ae0605386f2272288de7cf33abe` | Existing state mounts |
| flake-parts | `ea2630b7470978622c7689a1ff75d2b389175399` | Existing flake entry |
| Home Manager | `2c0c1f01521469cf0271180c453c79782d53c2f6` | `home-manager.users.wallyhao`, Noctalia option, Zsh/Foot/Niri options |
| Nixvim | `453dc9c5037e6d1bec81d2a51ddacd58a2f44e9c` | Minimal managed Neovim |

The first four existing root nodes were checked before and after adding the
two new inputs. Their locked objects did not change.

### Noctalia input decision

No separate Noctalia flake input is added. The locked nixpkgs contains
Noctalia 5.4.1, and the locked Home Manager already provides
`programs.noctalia` with `settings`, `customPalettes`, `systemd.enable`, and
the config validator. This keeps one Nixpkgs instance and uses the binary
cache. The package exposes the v5 `noctalia` CLI and `noctalia msg` IPC.
This avoids a second Nixpkgs (Noctalia's own flake input) and its build cost.

The source was inspected from the nixpkgs/Noctalia 5.4.1 package and the v5
documentation for the settings keys used here. The managed config is checked
with the actual package command `noctalia config validate`.

## Home Manager integration

`lib/mk-host.nix` adds `inputs.home-manager.nixosModules.home-manager` and
passes `inputs` as a NixOS `specialArgs`. `modules/nixos/home-manager.nix`
sets:

- `useGlobalPkgs = true`
- `useUserPackages = true`
- one user module from `inventory.users.wallyhao.homeModule`
- identity and `home.stateVersion` from inventory (`26.11`)

There is no standalone `homeConfigurations` output and no second deployment
command. The preview, real target (when storage is bound), and VM tests all
pass through the same `mk-host` path.

## Session and account integration

- `programs.niri.enable` uses the locked nixpkgs Niri package; Home Manager
  uses the same package and validates the generated KDL.
- `services.greetd` uses tuigreet on tty1 and starts `niri-session`. There is
  no `initial_session` and no autologin. tty2 is enabled as a rescue console.
- `systemd.defaultUnit` is `graphical.target` when desktop is enabled. The old
  phase-1 contract was updated to the intentional graphical entry point while
  retaining `getty.autologinUser = null`.
- The account patch now sets `security.pam.package` to a locally patched PAM
  package. This is narrower than a whole-closure
  `system.replaceDependencies` and still makes `pam_unix` resolve the userborn
  shadow symlink. The account VM must pass before this is considered complete.
- `services.gnome.gnome-keyring.enable = true`. Greetd deliberately has its
  own PAM rule stack, so the keyring auth/password/session modules are added
  explicitly; `login` and `passwd` also enable keyring integration.
- PipeWire/WirePlumber is the only audio server. PulseAudio's system daemon is
  disabled. `rtkit` is enabled.
- `xdg.portal` uses GTK for FileChooser and GNOME for sharing/Secret;
  `programs.niri.useNautilus = false`. No xwayland-satellite is added.
- TLP remains the only power policy executor; no power-profiles-daemon,
  auto-cpufreq, or tuned is enabled.

## Niri and Noctalia

The Niri settings are managed in Home Manager `settings`, not a raw copied
config. The keybindings are implemented in `binds.nix`; Noctalia IPC commands
are collected in `actions.nix`. `Super+Shift+R` and `Super+Shift+T` both open
the Noctalia session panel and never directly reboot or power off. `quit`
does not set `skip-confirmation`.

Noctalia uses one systemd user service, the `hearth` custom palette, a single
top bar, offline mode, no telemetry, no external-IP lookup, no weather/audio
visualizer, and its native Polkit agent. Clipboard history is capped at 100.
Noctalia is not spawned again from KDL.

## Fonts and appearance

The project-local palette was originally copied from `hearth-base16/hearth.json`.
It is now `assets/themes/emberlight.json`; the switch is recorded in
[phase3-decisions.md](phase3-decisions.md).
The locked nixpkgs does not contain the old `LXGW WenKai Mono GB` family
package; it provides `LXGW WenKai Mono` in `lxgw-wenkai`. The preference keeps
the old size (18) but uses the actually packaged family. The icon font is
`nerd-fonts.symbols-only`; `dejavu_fonts` is the basic UI fallback.

## Base CLI profile

`software/` is an independent flake/lock using the same nixpkgs revision.
`software/packages.nix` is the single package list:

`git`, `just`, `yazi`, `eza`, `bat`, `fd`, `ripgrep`, `fzf`, `zoxide`, `jq`,
`btop`, `unzip`.

Home Manager does not install Yazi. A small `hearth-yazi` wrapper checks for
`yazi` in PATH and prints the profile install command instead of silently
failing. Zsh's `y` does the same and changes the parent shell directory only
through Yazi's cwd file.

## State ownership

Home Manager owns `~/.config/niri`, `~/.config/foot`, `~/.config/noctalia`,
`~/.config/yazi`, Nixvim's generated config, and the shell configuration.
Runtime state is persisted only by the explicit whitelist in
`phase2-state.md`. Noctalia's UI settings may override the managed config in
`~/.local/state/noctalia/settings.toml`; that file is runtime state, not a
second managed configuration.

## 2026-11-10 VM harness correction

The disko harness now mounts the exported closure read-only at /nix/.ro-store
and provides a guest-private persistent overlay at /nix/store. The source
export itself is also read-only. The installed guest's real Nix database is
seeded with its closure registration; Home Manager uses real Nix commands
and native roots. The old successful-no-op Nix shim is removed.

Locked-source references: nixpkgs nixos/modules/tasks/filesystems/overlayfs.nix,
nixos/modules/virtualisation/qemu-vm.nix, nixos/tests/qemu-vm-store.nix.
The fixture's forced initrd module list explicitly includes overlay.
Production storage and both lock files are unchanged.

The graphical test's software EGL adapter also aligns Niri's primary lookup
with the Primary node on which its software GBM renderer is registered.
It is test-only; production Niri stays the unmodified locked package.
See phase2-blocker-vm.md for the original card0/renderD128 mismatch.

Tuigreet 0.11.1's crates/tuigreet/src/integration/remember.rs and keyboard.rs
confirm Escape cancels a remembered password conversation and returns to
Username. The login test uses that UI path and waits for each real prompt.
The test driver reboot method only types Ctrl+Alt+Delete; a graphical test
requests a guest systemctl reboot and checks kernel restart and changed
boot ID. None of those commands run on the host.

Two implementation omissions were repaired: y reads cwd with command cat
and retains failure status, and the Neovim undo directory is preserved.
The user-environment VM actually undoes a saved edit after reboot.

A further acceptance finding remains: shell.offline_mode does not stop the
plugin-source git acquisition attempts seen in the VM. Read the locked
Noctalia docs/user/plugins/index.mdx: plugins.auto_update uses the string
none, and plugins.source entries have an enabled switch. This follow-up
has not been implemented or reported as passed.

# Ember modules

`modules/` groups public modules by responsibility. A complex module is a directory with a
single `default.nix` entry point; a simple module is one `.nix` file.

| Module | Scope | Contents |
| --- | --- | --- |
| `system/` | NixOS | identity, accounts, boot, platform, hardware options, virtualisation, nixos-cli, foundation, memory, persistence |
| `network/` | NixOS | NetworkManager, resolved, firewall, Mihomo proxy |
| `power.nix` | NixOS | TLP and power policy |
| `session/` | NixOS | graphical session, PAM, portals, audio, system input method |
| `appearance/` | NixOS | Stylix, login, TTY appearance |
| `desktop/` | Home Manager | desktop options, theme, Waybar, Fuzzel, Mako, clipboard, lock, cursor, disk automount, profile session PATH/XDG |
| `niri/` | Home Manager | Niri configuration, actions, bindings, single-window service |
| `terminal/` | Home Manager | Foot, Zsh, direnv, terminal tools, Tmux |
| `nixvim/` | Home Manager | NixVim editor, LSP servers and CSS resources |
| `programs/` | Home Manager | configuration for profile-installed applications |
| `isaac/` | Home Manager | Isaac Sim / Isaac Lab FHS environment and launchers, enabled per host |
| `gaming.nix` | NixOS | Steam and the gaming runtime |

Consumers import only the public module path, never an internal file. For
example, `users/wallyhao/home.nix` imports `modules/desktop` and
`modules/niri`; it does not import `modules/desktop/waybar.nix`.

A directory module's `default.nix` imports its own regular `*.nix` files in
name order through `lib/module-dir.nix`; `default.nix` and `_`-prefixed files
are skipped. A file that takes its own arguments or is not a plain module keeps
an explicit list instead. The system module lists its base imports explicitly,
and the NixVim entry point imports the upstream Home Manager module. Adding a
`.nix` file to an auto-imported directory enables it; review new files as part
of the change that adds them.

Resources belong to the module that owns them. Niri scripts stay in
`modules/niri/`, p10k stays in `modules/terminal/resources/`, login assets stay
in `modules/appearance/resources/`, and Zen profile files stay in
`modules/programs/zen/`.

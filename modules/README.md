# Ember modules

`modules/` contains ten public modules. A complex module is a directory with a
single `default.nix` entry point; a simple module is one `.nix` file.

| Module | Scope | Contents |
| --- | --- | --- |
| `system/` | NixOS | identity, accounts, boot, platform, foundation, memory, persistence |
| `network/` | NixOS | NetworkManager, resolved, firewall, Mihomo proxy |
| `power.nix` | NixOS | TLP and power policy |
| `session/` | NixOS | graphical session, PAM, portals, audio, system input method |
| `appearance/` | NixOS | Stylix, login, TTY appearance |
| `desktop/` | Home Manager | desktop options, theme, Waybar, Fuzzel, Mako, clipboard, lock, cursor |
| `niri/` | Home Manager | Niri configuration, actions, bindings, single-window service |
| `terminal/` | Home Manager | Foot, Zsh, terminal tools |
| `apps/` | Home Manager | NixVim and profile PATH/desktop integration |
| `profile/` | Home Manager | configuration for profile-installed applications |

Consumers import only the public module path, never an internal file. For
example, `users/wallyhao/home.nix` imports `modules/desktop` and
`modules/niri`; it does not import `modules/desktop/waybar.nix`.

Resources belong to the module that owns them. Niri scripts stay in
`modules/niri/`, p10k stays in `modules/terminal/resources/`, login assets stay
in `modules/appearance/resources/`, and Zen profile files stay in
`modules/profile/zen/`.

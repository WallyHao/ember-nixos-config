# Phase 2 keybindings

Date: 2026-11-09. Modifier: **Super**. The implementation is
`modules/home/desktop/niri/binds.nix`; commands are collected in
`actions.nix`. No binding spawns a missing Folio application or a package that
phase 2 excludes.

| Key | Action | Verification |
| --- | --- | --- |
| `Super+Return` | `foot` | `vm-desktop`: Super+Return, then `id -u` typed in Foot returns 1000 |
| `Super+D` | `noctalia msg panel-toggle launcher` | Noctalia layer appears; VM screenshot |
| `Super+V` | `noctalia msg panel-toggle clipboard` | Noctalia layer appears after `wl-copy`; VM screenshot |
| `Super+C` | `noctalia msg panel-toggle control-center` | Config/eval contract; same command is used by `Super+P` |
| `Super+P` | Noctalia control center (replaces old panel) | Config/eval contract |
| `Super+Y` | `foot -e hearth-yazi` | Wrapper checks for `yazi` and prints install instructions when absent |
| `Super+Q` | `close-window` | Niri KDL validation |
| `Super+Tab` | `toggle-overview` | Niri KDL validation |
| `Super+Shift+Slash` | `show-hotkey-overlay` | Niri KDL validation |
| `Super+F` | `maximize-column` | Niri KDL validation |
| `Super+G` | `center-column` | Niri KDL validation |
| `Super+S` | full screenshot, no pointer | Niri KDL validation |
| `Super+Shift+S` | region screenshot, no pointer | Niri KDL validation |
| `Super+Left/Right` | focus column left/right | Niri KDL validation |
| `Super+Up/Down` | focus window up/down | Niri KDL validation |
| `Super+Shift+Left/Right` | move column left/right | Niri KDL validation |
| `Super+1..9`, `Super+0` | focus workspace 1..10 | Niri KDL validation |
| `Super+Shift+1..9`, `Super+Shift+0` | move window to workspace 1..10 | Niri KDL validation |
| `Super+Shift+E` | Niri `quit` with confirmation | VM: exit to greeter after Return confirmation |
| `Super+Shift+R` | Noctalia session panel (reboot choice) | VM: panel opens, Escape cancels; no direct reboot |
| `Super+Shift+T` | Noctalia session panel (shutdown choice) | Same panel; no direct poweroff |
| `XF86AudioRaiseVolume` | `noctalia msg volume-up` (allow when locked) | Config/eval; hardware effect manual |
| `XF86AudioLowerVolume` | `noctalia msg volume-down` (allow when locked) | Config/eval; hardware effect manual |
| `XF86AudioMute` | `noctalia msg volume-mute` (allow when locked) | Config/eval; hardware effect manual |
| `XF86MonBrightnessUp` | `noctalia msg brightness-up` (allow when locked) | Config/eval; hardware effect manual |
| `XF86MonBrightnessDown` | `noctalia msg brightness-down` (allow when locked) | Config/eval; hardware effect manual |
| `Super+W` | intentionally unbound; future browser key | Negative eval contract |
| `Super+N`, `Super+A` | intentionally unbound; old Portleaf/animation picker not migrated | Negative eval contract |
| `Super+Shift+Tab` | intentionally unbound; reverse switcher not enabled | Negative eval contract |

The Noctalia `session` panel is the confirmation surface for both reboot and
shutdown. It lists the actions and can be cancelled; the binding does not call
`session reboot` or `session shutdown` directly.

Screenshots use `~/Pictures/Screenshots`, already under the preserved
`Pictures` tree. The directory is created by Home Manager.

Volume and brightness are sent to Noctalia's IPC so there is one policy owner.
In the VM, no battery/backlight hardware is available; command wiring and
permissions can be checked, but the real hardware effect remains manual.

# Ember Home Manager modules

The inventory supplies identity. `ember.desktop.enable` bridges the system and
user session; no module reads the host account as the target account.

- appearance/ember.nix: Stylix palette bridge and explicit target ownership.
- desktop/niri: compositor and action bindings.
- desktop/waybar, launcher, notifications, input-method: Folio appearance,
  Emberlight colours; input-language observer is a small independent Folio port.
- desktop/security: Polkit agent, swaylock and swayidle. System PAM is separate.
- desktop/clipboard: runtime-only history, no plaintext persistent DB.
- desktop/wallpaper and session-tools: solid background, bounded controls/menus.
- terminal/editor/tools: Foot, P10k/eza/fzf, Nixvim, Yazi/OMP integration.
- shared/profile-session: native profile PATH and desktop-file discovery.

Desktop essentials are available before user profile bootstrap. Noctalia has no
live import or unit; retaining its old state directory is intentional rollback.

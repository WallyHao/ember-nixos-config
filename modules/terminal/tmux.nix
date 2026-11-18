{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Emberlight roles: base01 bar, base02 selection, base03 borders,
  # base04 muted, base05 text, base0D accent.
  c = config.lib.stylix.colors.withHashtag;

  # Absolute path: copy-mode bindings run without the interactive shell PATH.
  wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";

  # Private-use glyphs stay as JSON escapes so this file is pure ASCII and the
  # characters survive tooling that strips them.
  sep = builtins.fromJSON "\"\\uE0B0\"";
  iconDate = builtins.fromJSON "\"\\uF073\"";
  iconTime = builtins.fromJSON "\"\\uF017\"";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    # tmux comes from the software profile, so only the config is managed
    # here. tmux >= 3.1 reads $XDG_CONFIG_HOME/tmux/tmux.conf.
    xdg.configFile."tmux/tmux.conf".text = ''
      # Ember tmux config. Managed by modules/terminal/tmux.nix.
      set  -g default-terminal "tmux-256color"
      set  -g base-index 1
      setw -g pane-base-index 1
      set  -g history-limit 50000
      set  -s escape-time 0
      set  -g mouse on
      set  -g focus-events on
      set  -g set-clipboard on
      set  -g allow-passthrough on
      set  -g renumber-windows on
      set  -g status-keys vi
      set  -g mode-keys vi
      setw -g clock-mode-style 24
      set  -ga terminal-overrides ",foot*:Tc"

      # Emberlight bottom bar. Only the bar is customised; pane colours stay
      # with the terminal.
      set -g status-style "bg=${c.base01},fg=${c.base05}"
      set -g status-position bottom
      set -g status-justify centre
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 40

      # Session chip, closed by a powerline edge into the bar colour.
      set -g status-left "#[bg=${c.base0D},fg=${c.base00},bold] #S #[fg=${c.base0D},bg=${c.base01}]${sep} "

      # Window tabs: muted when inactive, accent chip for the current window.
      set -g window-status-format "#[fg=${c.base04},bg=${c.base01}] #I:#W "
      set -g window-status-current-format "#[bg=${c.base0D},fg=${c.base00},bold] #I:#W #[fg=${c.base0D},bg=${c.base01}]${sep} "
      set -g window-status-separator ""
      set -g window-status-activity-style "fg=${c.base0A},bg=${c.base01}"
      set -g window-status-bell-style "fg=${c.base08},bg=${c.base01},bold"

      # Date and time, muted, with Nerd Font icons.
      set -g status-right "#[fg=${c.base04},bg=${c.base01}] ${iconDate} %m-%d  ${iconTime} %H:%M "

      set -g pane-border-style "fg=${c.base03}"
      set -g pane-active-border-style "fg=${c.base0D}"
      set -g message-style "bg=${c.base02},fg=${c.base05}"
      set -g mode-style "bg=${c.base02},fg=${c.base07}"

      # Copy-mode: y (and mouse drag) yank to the Wayland clipboard so the
      # existing clipboard history keeps working.
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "${wlCopy}"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "${wlCopy}"
    '';
  };
}

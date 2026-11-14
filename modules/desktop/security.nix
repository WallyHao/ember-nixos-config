{
  config,
  lib,
  pkgs,
  ...
}:
let
  lock = pkgs.writeShellApplication {
    name = "ember-lock-start";
    runtimeInputs = [
      pkgs.systemd
      pkgs.wl-clipboard
      pkgs.swaylock
    ];
    text = ''
      systemctl --user stop ember-clipboard-watch.service wl-clip-persist.service
      wl-copy --clear || true
      if ! swaylock --daemonize; then
        systemctl --user start ember-clipboard-watch.service wl-clip-persist.service
        exit 1
      fi
    '';
  };
  resumeClipboard = pkgs.writeShellApplication {
    name = "ember-lock-finished";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      if systemctl --user is-active --quiet graphical-session.target; then
        systemctl --user start ember-clipboard-watch.service wl-clip-persist.service
      fi
    '';
  };
in
{
  config = lib.mkIf config.ember.desktop.enable {
    programs.swaylock.enable = true;
    services.swayidle = {
      enable = true;
      events.before-sleep = "${pkgs.systemd}/bin/systemctl --user start ember-lock.service";
      timeouts = [
        {
          timeout = 300;
          command = "${pkgs.systemd}/bin/systemctl --user start ember-lock.service";
        }
        {
          timeout = 600;
          command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
          resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
        }
      ];
    };
    systemd.user.services.ember-lock = {
      Unit = {
        Description = "Ember screen lock";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "forking";
        ExecStart = "${lock}/bin/ember-lock-start";
        ExecStopPost = "${resumeClipboard}/bin/ember-lock-finished";
        TimeoutStartSec = 15;
      };
    };
    systemd.user.services.ember-polkit = {
      Unit = {
        Description = "Ember Polkit authentication agent";
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "niri.service"
        ];
      };
      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5 = {
        waylandFrontend = true;
        addons = [
          (pkgs.fcitx5-rime.override { rimeDataPkgs = [ pkgs.rime-ice ]; })
          pkgs.fcitx5-gtk
        ];
        settings.inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "rime";
            Layout = "";
          };
          GroupOrder."0" = "Default";
        };
        settings.globalOptions = {
          "Hotkey/TriggerKeys"."0" = "Control+space";
          Behavior.ActiveByDefault = false;
        };
      };
    };
    # Native GTK/Foot use Wayland text-input. Qt on Niri needs the module.
    environment.sessionVariables.QT_IM_MODULE = "fcitx";
    systemd.user.services.ember-fcitx5 = {
      description = "Ember Fcitx5 input method";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [
        "graphical-session-pre.target"
        "niri.service"
      ];
      serviceConfig = {
        ExecStart = "${config.i18n.inputMethod.package}/bin/fcitx5";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}

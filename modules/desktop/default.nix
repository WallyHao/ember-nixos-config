{
  config,
  lib,
  osConfig,
  ...
}:
{
  options.ember.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = osConfig.ember.desktop.enable or true;
    description = "Bridge the system desktop switch into the Home Manager environment.";
  };

  options.ember.desktop.modifier = lib.mkOption {
    type = lib.types.str;
    default = "Super";
    description = "Niri modifier name used by the managed keybindings.";
  };

  options.ember.desktop.terminalFont = lib.mkOption {
    type = lib.types.str;
    default = "LXGW WenKai Mono GB:size=18";
    description = "Foot font string.";
  };

  imports = [
    ./theme.nix
    ./waybar.nix
    ./launcher.nix
    ./notifications.nix
    ./wallpaper.nix
    ./session-tools.nix
    ./security.nix
    ./clipboard.nix
    ./cursor.nix
    ./input-method.nix
  ];
}

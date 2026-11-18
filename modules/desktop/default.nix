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
    description = "Foot font string (`family:size=N`); the single source for every desktop font.";
  };

  options.ember.desktop.fontFamily = lib.mkOption {
    type = lib.types.str;
    default = lib.head (lib.splitString ":size=" config.ember.desktop.terminalFont);
    description = "Font family for the bar, notifications and input method.";
  };

  options.ember.desktop.fontSize = lib.mkOption {
    type = lib.types.int;
    default =
      if lib.hasInfix ":size=" config.ember.desktop.terminalFont then
        lib.toInt (lib.last (lib.splitString ":size=" config.ember.desktop.terminalFont))
      else
        18;
    description = "Point size for the bar, notifications and input method.";
  };

  imports = import ../../lib/module-dir.nix ./.;
}

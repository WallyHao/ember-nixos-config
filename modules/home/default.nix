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
    ./appearance/ember.nix
    ./shared/profile-session.nix
    ./desktop/niri
    ./desktop
    ./desktop/input-method.nix
    ./tools/omp.nix
    ./terminal/foot.nix
    ./terminal/tools.nix
    ./terminal/zsh.nix
    ./editor/nixvim.nix
    ./tools/yazi.nix
  ];
}

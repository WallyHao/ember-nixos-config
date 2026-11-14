# Adapted from Folio's fuzzel renderer: identical non-colour settings.
{ config, lib, ... }:
let
  c = config.ember.appearance.colors;
  hex = key: lib.removePrefix "#" c.${key} + "ff";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          icons-enabled = false;
          font = "LXGW WenKai Mono GB:size=18";
          dpi-aware = false;
          prompt = "Search> ";
          match-counter = true;
          show-actions = false;
          width = 40;
          lines = 8;
          horizontal-pad = 16;
          vertical-pad = 10;
          inner-pad = 8;
          layer = "overlay";
          exit-on-keyboard-focus-loss = true;
        };
        border = {
          width = 3;
          radius = 0;
        };
        colors = {
          background = hex "base00";
          text = hex "base05";
          prompt = hex "base0A";
          placeholder = hex "base04";
          input = hex "base05";
          match = hex "base0A";
          selection = hex "base01";
          selection-text = hex "base05";
          selection-match = hex "base0A";
          counter = hex "base04";
          border = hex "base08";
        };
      };
    };
  };
}

{
  config,
  lib,
  ...
}:
let
  stylix = config.lib.stylix.colors;
in
{
  config = lib.mkIf config.ember.desktop.enable {
    programs.foot = {
      enable = true;
      server.enable = false;
      settings = {
        # Stylix's native Foot target owns the colour table, alpha and
        # dpi-aware. Ember keeps its font and padding explicitly.
        main = {
          font = config.ember.desktop.terminalFont;
          pad = "15x15";
        };

        cursor = {
          style = "block";
          blink = "no";
        };

        colors-dark = {
          cursor = "${stylix.base00} ${stylix.base05}";
          selection-background = stylix.base02;
          selection-foreground = stylix.base05;
        };
      };
    };

    home.file."Pictures/Screenshots/.keep".text = "";
  };
}

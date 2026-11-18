{
  config,
  lib,
  ...
}:
let
  c = config.ember.appearance.colors;
  # Satty expects RRGGBBAA; Ember's palette values already carry the `#`.
  swatch = key: "${c.${key}}ff";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    # Satty is installed by the user profile; this only supplies its colours
    # and font so annotations match the rest of the desktop. The GTK chrome
    # follows Stylix's GTK target.
    xdg.configFile."satty/config.toml".text = ''
      [general]
      actions-on-enter = ["save-to-clipboard"]
      actions-on-escape = ["exit"]
      no-window-decoration = true

      [font]
      family = "${config.ember.desktop.fontFamily}"
      style = "Regular"

      [color-palette]
      palette = [
        "${swatch "base08"}"
        "${swatch "base09"}"
        "${swatch "base0A"}"
        "${swatch "base0B"}"
        "${swatch "base0C"}"
        "${swatch "base0D"}"
        "${swatch "base0E"}"
        "${swatch "base05"}"
      ]
    '';
  };
}

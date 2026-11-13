{
  config,
  lib,
  ...
}:
let
  stylix = config.lib.stylix.colors;
  baseKeys = [
    "base00"
    "base01"
    "base02"
    "base03"
    "base04"
    "base05"
    "base06"
    "base07"
    "base08"
    "base09"
    "base0A"
    "base0B"
    "base0C"
    "base0D"
    "base0E"
    "base0F"
  ];
in
{
  options.ember.appearance = {
    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Project-local palette name, as resolved by Stylix.";
    };

    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      description = "Base16 palette shared by the managed desktop components, with leading #.";
    };
  };

  config = {
    # Compatibility interface for the Ember adapters. Values come from the
    # scheme Stylix already resolved; no adapter reads the JSON asset again.
    ember.appearance.name = stylix.scheme;
    ember.appearance.colors = lib.genAttrs baseKeys (key: stylix.withHashtag.${key});

    gtk.enable = true;
    stylix = {
      enable = true;
      autoEnable = false;

      targets = {
        # The native Foot target owns the colour table. Its font slice is
        # disabled because Ember keeps the installed LXGW WenKai Mono 18.
        foot = {
          enable = true;
          fonts.enable = false;
        };

        # These screens have reviewed Ember adapters of their own and must
        # not be rewritten by a generic Stylix target.
        fcitx5.enable = false;
        fzf.enable = false;
        waybar.enable = false;
        fuzzel.enable = false;
        mako.enable = false;
        swaylock.enable = true;
        gtk.enable = true;
        nixvim.enable = false;
      };
    };

    assertions = [
      {
        assertion = stylix.scheme != "untitled" && stylix.withHashtag ? base00;
        message = "Home Manager did not receive the reviewed Ember scheme from the system Stylix configuration.";
      }
    ];
  };
}

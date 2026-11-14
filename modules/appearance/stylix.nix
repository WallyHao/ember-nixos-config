{ lib, pkgs, ... }:
let
  # The only manually maintained palette input. Stylix normalises it into
  # `config.lib.stylix.colors`; every consumer below derives from that result.
  source = builtins.fromJSON (builtins.readFile ../../assets/themes/emberlight.json);

  scheme = source.palette // {
    inherit (source) author system variant;
    scheme = source.name;
    # base16.nix derives file slugs from `slug`/`name`; without it the
    # generated palette files are named "untitled".
    slug = lib.toLower (builtins.replaceStrings [ " " ] [ "-" ] source.name);
  };
in
{
  imports = [ ./login.nix ];
  stylix = {
    enable = true;
    # Only the reviewed targets are enabled. This keeps Stylix from taking
    # over fonts, GTK/Qt, cursors or software that Ember configures itself.
    autoEnable = false;
    polarity = "dark";
    image = null;
    base16Scheme = scheme;
    targets.console.enable = true;
    fonts = {
      monospace = {
        package = import ../../packages/lxgw-wenkai-gb.nix { inherit pkgs; };
        name = "LXGW WenKai Mono GB";
      };
      sansSerif = {
        package = import ../../packages/lxgw-wenkai-gb.nix { inherit pkgs; };
        name = "LXGW WenKai GB";
      };
      sizes = {
        desktop = 18;
        popups = 18;
        terminal = 18;
        applications = 18;
      };
    };
  };

  assertions = [
    {
      assertion = scheme.system == "base16";
      message = "assets/themes/emberlight.json must stay a Base16 scheme.";
    }
    {
      assertion = builtins.length (builtins.attrNames source.palette) == 16;
      message = "assets/themes/emberlight.json must define exactly base00..base0F.";
    }
  ];
}

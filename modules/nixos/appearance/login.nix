# ANSI is a format adapter: RGB ownership stays with Stylix's console target.
{ config, lib, ... }:
let
  c = config.lib.stylix.colors;
  esc = builtins.fromJSON ''"\u001b"'';
  roles = {
    container = "black";
    text = "white";
    border = "black";
    title = "yellow";
    greet = "yellow";
    prompt = "yellow";
    input = "white";
    time = "white";
    action = "white";
    button = "yellow";
  };
in
{
  options.ember.appearance.login = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    readOnly = true;
    description = "Login roles resolved against the native Stylix console palette.";
  };
  config = {
    ember.appearance.login = {
      theme = lib.concatStringsSep ";" (lib.mapAttrsToList (key: value: "${key}=${value}") roles);
      logoPrimary = "${esc}[33m";
      logoSecondary = "${esc}[31m";
      reset = "${esc}[0m";
    };
    assertions = [
      {
        assertion =
          builtins.length config.console.colors == 16
          && lib.toLower (builtins.elemAt config.console.colors 0) == c.base00
          && lib.toLower (builtins.elemAt config.console.colors 1) == c.base08
          && lib.toLower (builtins.elemAt config.console.colors 3) == c.base0A;
        message = "Login ANSI roles must match the locked Stylix Emberlight console mapping.";
      }
    ];
  };
}

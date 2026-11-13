{
  config,
  lib,
  ...
}:
let
  # The persisted Zen profile created by the original profile migration.
  profile = "eryfevl7.Default Profile";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.file = {
      ".config/zen/${profile}/chrome/userChrome.css".source = ./zen/userChrome.css;
      ".config/zen/${profile}/chrome/userContent.css".source = ./zen/userContent.css;
      ".config/zen/${profile}/user.js".source = ./zen/user.js;
    };
  };
}

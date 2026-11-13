{
  config,
  lib,
  ...
}:
let
  profile = "${config.home.homeDirectory}/.local/state/nix/profiles/profile";
  systemShare = "/etc/profiles/per-user/${config.home.username}/share";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.sessionPath = [
      "${profile}/bin"
      "${config.home.homeDirectory}/.local/bin"
    ];

    # Keep the native user profile and the system profile discoverable without
    # replacing the session imported by niri-session.
    home.sessionVariables.XDG_DATA_DIRS = lib.mkForce (
      "${profile}/share:${config.home.homeDirectory}/.local/share:${systemShare}:/run/current-system/sw/share:/usr/share"
    );
  };
}

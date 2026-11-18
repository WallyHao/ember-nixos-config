{
  config,
  lib,
  ...
}:
let
  profile = "${config.home.homeDirectory}/.local/state/nix/profiles/profile";
  systemShare = "/etc/profiles/per-user/${config.home.username}/share";
  persistHome = "/persist/home/${config.home.username}";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.sessionPath = [
      "${profile}/bin"
      "${config.home.homeDirectory}/.local/bin"
      # npm global entry points installed under NPM_CONFIG_PREFIX below.
      "${persistHome}/.npm-global/bin"
    ];

    # niri-session re-execs the login shell and then imports that environment
    # into the systemd user manager and D-Bus. These values make the native
    # user profile's binaries and desktop entries visible to the whole
    # graphical session, not only to interactive shells.
    home.sessionVariables = {
      XDG_DATA_DIRS = lib.mkForce (
        "${profile}/share:${config.home.homeDirectory}/.local/share:${systemShare}:/run/current-system/sw/share:/usr/share"
      );
      # npm's default global prefix is the read-only Nix store Node.js
      # package. Point global installs at persistent storage instead so
      # `npm install -g` works and survives the tmpfs root.
      NPM_CONFIG_PREFIX = "${persistHome}/.npm-global";
      # Codex keeps auth.json (OAuth tokens), config.toml and sessions here.
      CODEX_HOME = "${persistHome}/.codex";
    };
  };
}

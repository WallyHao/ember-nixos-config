{
  config,
  lib,
  pkgs,
  ...
}:
let
  yaziCommand = pkgs.writeShellScriptBin "ember-yazi" ''
    set -eu
    if ! command -v yazi >/dev/null 2>&1; then
      printf '%s\n' 'Yazi is not installed yet.' 'Install the base user profile with:' \
        '  just profile install'
      sleep 8
      exit 127
    fi
    exec yazi "$@"
  '';
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.packages = [
      yaziCommand
      (pkgs.writeShellScriptBin "hearth-yazi" ''exec ${yaziCommand}/bin/ember-yazi "$@"'')
    ];

    xdg.configFile."yazi/yazi.toml".text = ''
      [manager]
      ratio = [1, 4, 3]
      show_hidden = false
      linemode = "size"
    '';
  };
}

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  upstream = inputs.nixos-cli.packages.${pkgs.stdenv.hostPlatform.system}.nixos-cli;
  refresh = import ../maintenance/refresh.nix { inherit config lib pkgs; };
  entry = pkgs.writeShellApplication {
    name = "nixos";
    text = ''
      if [[ "''${1:-}" == refresh ]]; then
        shift
        exec ${lib.getExe refresh} "$@"
      fi
      exec ${lib.getExe upstream} "$@"
    '';
  };
in
{
  programs.nixos-cli = {
    enable = true;
    package = pkgs.symlinkJoin {
      inherit (upstream) pname version meta;
      paths = [ upstream ];
      postBuild = ''
        rm "$out/bin/nixos"
        ln -s ${lib.getExe entry} "$out/bin/nixos"
      '';
    };
    settings = {
      # `path:` includes untracked files, matching how this repository is
      # built and tested. Keeping the flake here works from any shell,
      # including zsh, which does not source /etc/profile.
      config_location = "path:${config.ember.userHome}/Workspace/ember-nixos-config";
      apply = {
        reexec_as_root = true;
        use_git_commit_msg = true;
      };
      root.command = "sudo";
    };
  };
}

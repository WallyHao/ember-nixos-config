{ config, pkgs, ... }:
{
  imports = [
    ../../modules/desktop
    ../../modules/niri
    ../../modules/terminal
    ../../modules/nixvim
    ../../modules/programs
    ./git.nix
    ./preferences.nix
  ];

  home.packages = [
    (pkgs.callPackage ../../packages/qwerty-learner.nix {
      inherit (config.ember.appearance) colors;
      inherit (config.stylix) polarity;
    })
  ];
}

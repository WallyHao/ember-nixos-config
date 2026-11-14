{ pkgs }:
let
  cliNames = [
    "gh"
    "git"
    "just"
    "yazi"
    "eza"
    "bat"
    "fd"
    "ripgrep"
    "fzf"
    "zoxide"
    "jq"
    "btop"
    "unzip"
  ];

  userPackages = import ./selection/user-packages.nix;

  localPackages = {
    omp = pkgs.callPackage ./packages/omp.nix { };
    zen = import ./packages/zen.nix { inherit pkgs; };
  };

  names = cliNames ++ [ "omp" ] ++ userPackages.packages;
in
assert pkgs.lib.assertMsg (
  builtins.length names == builtins.length (pkgs.lib.unique names)
) "Ember profile package list contains duplicate names";
pkgs.lib.genAttrs names (
  name: localPackages.${name} or pkgs.${name} or (throw "Unknown Ember profile package: ${name}")
)

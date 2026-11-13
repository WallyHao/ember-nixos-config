{ pkgs }:
let
  names = [
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

  userPackages = import ./user-packages.nix;
  localPackages.zen = import ./zen.nix { inherit pkgs; };
  applications = map (name: localPackages.${name} or pkgs.${name}) userPackages.packages;

  single = pkgs.lib.genAttrs names (name: pkgs.${name});

  base = pkgs.buildEnv {
    name = "ember-base";
    paths = map (name: pkgs.${name}) names;
  };
  omp = pkgs.callPackage ./omp.nix { };
  workstation = pkgs.buildEnv {
    name = "ember-workstation";
    paths = [
      base
      omp
    ]
    ++ applications;
  };
in
single // localPackages // { inherit base omp workstation; }

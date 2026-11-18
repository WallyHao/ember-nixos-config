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
    "grim"
    "slurp"
    "satty"
    "atuin"
    "tmux"
  ];

  userPackages = import ./selection/user-packages.nix;

  # Language runtimes and package managers belong in the declared profile, not
  # ad-hoc `nix profile install`. Project dependencies stay with the language's
  # own lockfile (uv.lock / pnpm-lock.yaml).
  devNames = [
    "uv"
    "nodejs_24"
    "pnpm"
  ];

  localPackages = {
    omp = pkgs.callPackage ./packages/omp.nix { };
    zen = import ./packages/zen.nix { inherit pkgs; };
    # Not exposed as a top-level nixpkgs attribute.
    turbostat = pkgs.linuxPackages.turbostat;
  };

  names = cliNames ++ devNames ++ [ "omp" ] ++ userPackages.packages;
in
assert pkgs.lib.assertMsg (
  builtins.length names == builtins.length (pkgs.lib.unique names)
) "Ember profile package list contains duplicate names";
pkgs.lib.genAttrs names (
  name: localPackages.${name} or pkgs.${name} or (throw "Unknown Ember profile package: ${name}")
)

{
  description = "Ember user profile package set";

  inputs.nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/f4a03c008967841f2a0b3cb7c436fc6fc31671f6.tar.gz";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfreePredicate =
            (import ./policy.nix {
              inherit (nixpkgs) lib;
            }).allowUnfreePredicate;
        };
      };
    in
    {
      packages.${system} = import ./package-set.nix { inherit pkgs; };
    };
}

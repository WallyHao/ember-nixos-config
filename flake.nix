{
  description = "Ember: Emberlight Niri laptop configuration";

  inputs = {
    nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/f4a03c008967841f2a0b3cb7c436fc6fc31671f6.tar.gz";
    flake-parts.url = "https://github.com/hercules-ci/flake-parts/archive/ea2630b7470978622c7689a1ff75d2b389175399.tar.gz";
    disko = {
      url = "https://github.com/nix-community/disko/archive/cedd626e11b635470fa6f9fdb8ad79b0075dd7f9.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    preservation.url = "https://github.com/nix-community/preservation/archive/00be7f7dd1a11ae0605386f2272288de7cf33abe.tar.gz";

    home-manager = {
      url = "https://github.com/nix-community/home-manager/archive/2c0c1f01521469cf0271180c453c79782d53c2f6.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "https://github.com/nix-community/nixvim/archive/453dc9c5037e6d1bec81d2a51ddacd58a2f44e9c.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Single colour source for phase 3. Pinned to the Stylix revision that
    # targets NixOS/Home Manager 26.11; existing root inputs are not updated.
    stylix = {
      url = "https://github.com/nix-community/stylix/archive/3e27b6c499e507df6e3bb8eca3614f5c95e28140.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Unified NixOS tooling; pinned to the 0.16.1 release commit.
    nixos-cli = {
      url = "https://github.com/nix-community/nixos-cli/archive/c271826e6cc755268b56269837e05c0ff9de5101.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        ./flake/hosts.nix
        ./flake/modules.nix
        ./flake/checks.nix
        ./flake/development.nix
      ];
    };
}

{
  inputs,
  ...
}:
{
  flake.nixosModules.default = {
    imports = [
      inputs.preservation.nixosModules.preservation
      ../modules/nixos/default.nix
    ];
  };
}

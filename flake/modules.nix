{
  inputs,
  ...
}:
{
  flake.nixosModules.default = {
    imports = [
      inputs.preservation.nixosModules.preservation
      ../modules/system/default.nix
    ];
  };
}

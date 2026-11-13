{
  inputs,
  lib,
  ...
}:
let
  inventory = import ../inventory;
  evaluated = import ../lib/eval-inventory.nix {
    inherit lib inventory;
  };
  deployment = import ../lib/deployment.nix {
    inherit inventory;
  };
  host = evaluated.hosts.ember;
  mkHost = import ../lib/mk-host.nix;

  portable = mkHost {
    inherit inputs inventory;
    hostName = "ember";
    hardwareModule = host.physicalHardwareModule;
  };
in
{
  flake = {
    # A real target is exported only after the disk identity, layout and
    # confirmation exist in inventory. Until then there is deliberately no
    # nixosConfigurations.ember.
    nixosConfigurations = lib.optionalAttrs deployment.installable rec {
      ember =
        (mkHost {
          inherit inputs inventory;
          hostName = "ember";
          hardwareModule = host.physicalHardwareModule;
          storageModule = host.storage.layoutModule;
        }).system;
      # Transitional alias builds the same Ember hostname.
      hearth = ember;
    };

    nixosModules.emberLaptop = {
      imports = portable.modules;
    };

    lib.ember.deployment = deployment;
    lib.hearth.deployment = deployment;
    nixosModules.hearthLaptop = {
      imports = portable.modules;
    };
  };
}

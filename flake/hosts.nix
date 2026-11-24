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
  mkHost = import ../lib/mk-host.nix;
  hostNames = builtins.attrNames evaluated.hosts;

  deployments = lib.genAttrs hostNames (
    hostName:
    import ../lib/deployment.nix {
      inherit inventory hostName;
    }
  );

  makeHost =
    hostName: storageModule:
    mkHost {
      inherit inputs inventory hostName;
      hardwareModules = evaluated.hosts.${hostName}.hardwareModules;
      inherit storageModule;
    };

  # A real target is exported only after that host's disk identity, layout and
  # confirmation exist in inventory.
  configurations = lib.mapAttrs (
    hostName: _: (makeHost hostName evaluated.hosts.${hostName}.storage.layoutModule).system
  ) (lib.filterAttrs (hostName: _: deployments.${hostName}.installable) evaluated.hosts);

  portableModules = hostName: (makeHost hostName null).modules;
in
{
  flake = {
    nixosConfigurations =
      configurations // lib.optionalAttrs (configurations ? ember) { hearth = configurations.ember; };

    nixosModules = lib.optionalAttrs (evaluated.hosts ? ember) {
      emberLaptop = {
        imports = portableModules "ember";
      };
      hearthLaptop = {
        imports = portableModules "ember";
      };
    };

    lib = {
      inherit deployments;
    }
    // lib.optionalAttrs (deployments ? ember) {
      ember.deployment = deployments.ember;
      hearth.deployment = deployments.ember;
    };
  };
}

# Contracts for hand-written gates only: inventory validation, the deployment
# binding, and mutually exclusive power daemons. Declarative option values are
# covered by evaluating the real system and the preview, not re-pinned here.
{
  inputs,
  inventory,
  deployment,
}:
let
  lib = inputs.nixpkgs.lib;
  schema = import ../../inventory/schema.nix;
  mkHost = import ../../lib/mk-host.nix;

  preview = mkHost {
    inherit inputs inventory;
    hostName = "ember";
    hardwareModule = inventory.hosts.ember.physicalHardwareModule;
    storageModule = ../fixtures/storage.nix;
  };

  unboundDeployment = import ../../lib/deployment.nix {
    inventory = lib.recursiveUpdate inventory {
      hosts.ember.storage = {
        targetDisk = null;
        layoutModule = null;
        layoutConfirmed = false;
      };
    };
  };

  checks = {
    storage-bound = deployment.storageBound && deployment.installable;
    # The serializable deployment state consumed by `scripts/ember info`.
    storage-reason = deployment.reason != "" && deployment.storageBound == deployment.installable;
    unbound-target-gate = !unboundDeployment.storageBound && !unboundDeployment.installable;
  };

  failed = builtins.filter (name: checks.${name} != true) (builtins.attrNames checks);

  mustFail =
    name: value:
    let
      result = builtins.tryEval value;
    in
    if result.success then throw "negative eval contract did not fail: ${name}" else name;

  baseUser = inventory.users.wallyhao;
  duplicateUidInventory = inventory // {
    users = inventory.users // {
      wallyhao2 = baseUser // {
        name = "wallyhao2";
      };
    };
    hosts = inventory.hosts // {
      ember = inventory.hosts.ember // {
        users = [
          "wallyhao"
          "wallyhao2"
        ];
      };
    };
  };
  missingUserInventory = inventory // {
    hosts = inventory.hosts // {
      ember = inventory.hosts.ember // {
        users = [ "missing" ];
      };
    };
  };
  partialStorageInventory = inventory // {
    hosts = inventory.hosts // {
      ember = inventory.hosts.ember // {
        storage = {
          targetDisk = "/dev/vda";
          layoutModule = null;
          layoutConfirmed = false;
        };
      };
    };
  };

  negative = [
    (mustFail "duplicate-uid" (schema {
      inherit lib;
      inventory = duplicateUidInventory;
    }))
    (mustFail "missing-user" (schema {
      inherit lib;
      inventory = missingUserInventory;
    }))
    (mustFail "partial-storage" (schema {
      inherit lib;
      inventory = partialStorageInventory;
    }))
    (mustFail "tlp-with-ppd" (
      (lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = preview.modules ++ [
          {
            services.tlp.enable = true;
            services.power-profiles-daemon.enable = true;
          }
        ];
      }).config.system.build.toplevel.drvPath
    ))
  ];

  negativeNames = map (x: x) negative;
in
if failed != [ ] then
  throw "ember eval contracts failed: ${builtins.concatStringsSep ", " failed}"
else
  checks
  // {
    inherit (deployment) storageBound installable;
    negative = negativeNames;
  }

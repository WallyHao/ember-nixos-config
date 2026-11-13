{
  inputs,
  inventory,
  hostName,
  hardwareModule,
  storageModule ? null,
  extraModules ? [ ],
  usePersistenceModule ? true,
}:
let
  lib = inputs.nixpkgs.lib;
  evaluated = import ./eval-inventory.nix {
    inherit lib inventory;
  };
  host = evaluated.hosts.${hostName};
  userName = builtins.head host.users;
  user = evaluated.users.${userName};

  identityModule =
    { ... }:
    {
      ember.hostName = host.hostName;
      ember.stateVersion = host.stateVersion;
      ember.userName = user.name;
      ember.userUid = user.uid;
      ember.userHome = user.home;
      ember.initialHashedPassword = user.initialHashedPassword;
      ember.userExtraGroups = user.extraGroups;
      ember.homeModule = user.homeModule;
      ember.homeStateVersion = user.homeStateVersion;
    };

  persistenceModules = lib.optional usePersistenceModule user.persistenceModule;
  storageModules =
    lib.optional (storageModule != null) inputs.disko.nixosModules.disko
    ++ lib.optional (storageModule != null) storageModule;

  modules = [
    inputs.preservation.nixosModules.preservation
    inputs.stylix.nixosModules.stylix
    ../modules/nixos/default.nix
    host.hostModule
    hardwareModule
    identityModule
    ../modules/nixos/home-manager.nix
    inputs.home-manager.nixosModules.home-manager
  ]
  ++ persistenceModules
  ++ storageModules
  ++ extraModules;

  system = lib.nixosSystem {
    inherit (host) system;
    specialArgs = { inherit inputs; };
    modules = modules;
  };
in
{
  inherit
    host
    user
    modules
    system
    ;
}

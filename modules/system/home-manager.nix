{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.ember;
in
{
  home-manager = {
    # Preserve regular user files when HM first takes ownership during migration.
    backupFileExtension = "pre-ember";
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
    };

    users.${cfg.userName} = {
      imports = [ cfg.homeModule ];

      home = {
        username = cfg.userName;
        homeDirectory = cfg.userHome;
        stateVersion = cfg.homeStateVersion;
      };
    };
  };
}

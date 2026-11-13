{
  config,
  lib,
  ...
}:
let
  cfg = config.ember;
in
{
  options.ember = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "Target hostname, supplied only by the inventory.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Literal system.stateVersion baseline for this installation.";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      description = "Primary normal user.";
    };

    userUid = lib.mkOption {
      type = lib.types.int;
      description = "UID of the primary normal user.";
    };

    userHome = lib.mkOption {
      type = lib.types.str;
      description = "Absolute home directory of the primary user.";
    };

    initialHashedPassword = lib.mkOption {
      type = lib.types.str;
      description = "SHA-512 crypt hash used only for the initial account creation.";
    };

    userExtraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Initial supplementary groups for the primary user.";
    };

    homeModule = lib.mkOption {
      type = lib.types.path;
      description = "Home Manager module owned by the primary user.";
    };

    homeStateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Literal Home Manager stateVersion baseline for this user.";
    };
  };

  config = {
    networking.hostName = cfg.hostName;
    system.stateVersion = cfg.stateVersion;
  };
}

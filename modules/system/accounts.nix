{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ember;
in
{
  # userborn exposes /etc/shadow as a symlink to the persistent password
  # database. pam_unix's password update writes a temporary file in /etc and
  # renames it over /etc/shadow, which replaces the symlink and loses the
  # update on the volatile root. This local compatibility patch resolves the
  # symlink and performs the atomic rename in the target directory instead.
  #
  # Use the patched PAM only for the PAM service stack. This avoids a global
  # PAM rebuild while still making pam_unix resolve the persistent shadow
  # symlink before its atomic rename.
  security.pam.package = pkgs.pam.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/pam-unix-password-symlink.patch ];
  });

  programs.zsh.enable = true;

  users.mutableUsers = true;

  users.users.${cfg.userName} = {
    isNormalUser = true;
    uid = cfg.userUid;
    home = cfg.userHome;
    group = "users";
    extraGroups = cfg.userExtraGroups;
    shell = pkgs.zsh;
    createHome = true;
    initialHashedPassword = cfg.initialHashedPassword;
  };

  # No root password login and no autologin. The target account is the only
  # normal account with an initial credential; root keeps the NixOS default
  # locked password entry.
  services.getty.autologinUser = lib.mkForce null;

  # The home directory must exist before user services, but shell files are
  # owned by Home Manager. Do not pre-create .zshrc: that would both trigger a
  # conflict and defeat the managed configuration.
  systemd.tmpfiles.rules = [
    "d ${cfg.userHome} 0755 ${cfg.userName} users -"
  ];

  security.sudo.wheelNeedsPassword = true;

  # userborn owns the password database outside the volatile /etc. The
  # persistence module orders userborn after the preserved mounts.
  services.userborn.enable = true;
  services.userborn.passwordFilesLocation = "/var/lib/nixos";
  services.userborn.importLegacyState = false;

  assertions = [
    {
      assertion = config.users.users.${cfg.userName}.hashedPassword == null;
      message = "wallyhao must use only initialHashedPassword, not hashedPassword.";
    }
    {
      assertion = config.users.users.${cfg.userName}.hashedPasswordFile == null;
      message = "wallyhao must not use hashedPasswordFile.";
    }
    {
      assertion = config.users.users.${cfg.userName}.password == null;
      message = "wallyhao must not use a declarative password.";
    }
  ];
}

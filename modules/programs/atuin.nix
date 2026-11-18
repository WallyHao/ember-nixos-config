{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    # History stays local to this machine: no sync endpoint and no update
    # checks. The shell integration is added by modules/terminal/zsh.nix.
    xdg.configFile."atuin/config.toml".text = ''
      auto_sync = false
      update_check = false
    '';
  };
}

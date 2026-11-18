{
  lib,
  ...
}:
{
  # Commit identity, declared instead of `git config --global`: the global
  # file is a read-only Home Manager store link, so imperative writes fail.
  # Home Manager concatenates the `text` lines of this declaration and
  # modules/terminal/git.nix into one config file.
  xdg.configFile."git/config".text = lib.generators.toGitINI {
    user = {
      name = "WallyHao";
      email = "wallyhao@qq.com";
    };
  };
}

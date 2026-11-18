{
  lib,
  ...
}:
{
  # `gh auth setup-git` writes the credential helper into ~/.gitconfig, which
  # lives on the tmpfs root and disappears at reboot. Declare the same helper
  # here instead. gh comes from the separate software profile, which is on
  # PATH for PAM sessions and interactive shells, so no store path is baked in.
  xdg.configFile."git/config".text = lib.generators.toGitINI {
    credential = {
      "https://github.com".helper = "!gh auth git-credential";
      "https://gist.github.com".helper = "!gh auth git-credential";
    };
  };
}

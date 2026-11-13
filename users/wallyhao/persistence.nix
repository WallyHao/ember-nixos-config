{
  preservation.preserveAt."/persist".users.wallyhao.directories = [
    {
      directory = ".config/fcitx5";
      mode = "0700";
    }
    {
      directory = ".local/share/fcitx5";
      mode = "0700";
    }
    {
      directory = ".omp";
      mode = "0700";
    }
    {
      directory = ".config/zen";
      mode = "0700";
    }
    ".local/state/nix"
    {
      directory = ".local/state/nix/profiles";
      mode = "0755";
    }
    {
      directory = ".local/state/zsh";
      mode = "0700";
    }
    {
      # Retained for rollback only; Ember never launches or migrates Noctalia.
      directory = ".local/state/noctalia";
      mode = "0700";
    }
    {
      directory = ".local/share/keyrings";
      mode = "0700";
    }
    {
      directory = ".local/state/nvim/undo";
      mode = "0700";
    }
    "Workspace"
    "Documents"
    "Downloads"
    "Pictures"
    "Pictures/Screenshots"
  ];
}

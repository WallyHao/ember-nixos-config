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
    {
      # gh keeps the host registry (hosts.yml) and its config here. The OAuth
      # token lives in the keyring below, but without hosts.yml gh reports no
      # authenticated hosts on every boot.
      directory = ".config/gh";
      mode = "0700";
    }
    ".local/state/nix"
    {
      directory = ".local/state/nix/profiles";
      mode = "0755";
    }
    {
      directory = ".local/state/ember-refresh";
      mode = "0700";
    }
    {
      # file-drop reads its basic-auth credentials here; on the tmpfs root the
      # service would otherwise come up with a fresh password after every boot.
      directory = ".local/state/file-drop";
      mode = "0700";
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
      # Steam library, Proton prefixes and shader caches. The tmpfs root
      # would otherwise discard every installed game at shutdown.
      directory = ".local/share/Steam";
      mode = "0700";
    }
    {
      directory = ".local/share/keyrings";
      mode = "0700";
    }
    {
      # Atuin keeps shell history here; never point XDG data at this.
      directory = ".local/share/atuin";
      mode = "0700";
    }
    {
      # direnv stores its allow database here. On the tmpfs root every
      # `direnv allow` would otherwise be discarded at reboot, leaving each
      # .envrc blocked again.
      directory = ".local/share/direnv";
      mode = "0700";
    }
    {
      directory = ".local/state/nvim/undo";
      mode = "0700";
    }
    {
      # uv puts interpreter shims and `uv tool install` entry points here; the
      # directory is already on PATH via modules/desktop/profile-session.nix.
      directory = ".local/bin";
      mode = "0700";
    }
    {
      # uv-managed interpreters and installed tools live here; the tmpfs root
      # would otherwise discard every Python on shutdown.
      directory = ".local/share/uv";
      mode = "0700";
    }
    {
      directory = ".cache/uv";
      mode = "0700";
    }
    {
      # pnpm content-addressable store and global bin directory.
      directory = ".local/share/pnpm";
      mode = "0700";
    }
    "Workspace"
    "Documents"
    "Downloads"
    "Pictures"
    "Pictures/Screenshots"
  ];
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;

  yaziCommand = pkgs.writeShellScriptBin "ember-yazi" ''
    set -eu
    if ! command -v yazi >/dev/null 2>&1; then
      printf '%s\n' 'Yazi is not installed yet.' 'Install the user profile with:' \
        '  just apps'
      sleep 8
      exit 127
    fi
    exec yazi "$@"
  '';
in
{
  config = lib.mkIf config.ember.desktop.enable {
    home.packages = [
      yaziCommand
      (pkgs.writeShellScriptBin "hearth-yazi" ''exec ${yaziCommand}/bin/ember-yazi "$@"'')
    ];

    xdg.configFile."yazi/yazi.toml".text = ''
      [manager]
      ratio = [1, 4, 3]
      show_hidden = false
      linemode = "size"
    '';

    # Yazi's bundled theme and icon tables carry hardcoded upstream colors.
    # Replace every style and icon-rule color with the Emberlight palette.
    xdg.configFile."yazi/theme.toml".text = ''
      [app]
      overall = { bg = "${c.base00}" }

      [mgr]
      cwd = { fg = "${c.base0D}" }
      find_keyword = { fg = "${c.base0A}", bold = true, underline = true }
      find_position = { fg = "${c.base0E}", bold = true }
      symlink_target = { fg = "${c.base0C}", italic = true }

      marker_copied = { fg = "${c.base0B}", bg = "${c.base0B}" }
      marker_cut = { fg = "${c.base08}", bg = "${c.base08}" }
      marker_marked = { fg = "${c.base0C}", bg = "${c.base0C}" }
      marker_selected = { fg = "${c.base0A}", bg = "${c.base0A}" }
      marker_symbol = "│"

      count_copied = { fg = "${c.base00}", bg = "${c.base0B}" }
      count_cut = { fg = "${c.base00}", bg = "${c.base08}" }
      count_selected = { fg = "${c.base00}", bg = "${c.base0A}" }

      border_symbol = "│"
      border_style = { fg = "${c.base03}" }

      [tabs]
      active = { fg = "${c.base00}", bg = "${c.base0D}", bold = true }
      inactive = { fg = "${c.base0D}", bg = "${c.base02}" }

      [mode]
      normal_main = { fg = "${c.base00}", bg = "${c.base0D}", bold = true }
      normal_alt = { fg = "${c.base0D}", bg = "${c.base02}" }
      select_main = { fg = "${c.base00}", bg = "${c.base08}", bold = true }
      select_alt = { fg = "${c.base08}", bg = "${c.base02}" }
      unset_main = { fg = "${c.base00}", bg = "${c.base09}", bold = true }
      unset_alt = { fg = "${c.base09}", bg = "${c.base02}" }

      [indicator]
      parent = { fg = "${c.base03}", reversed = true }
      current = { fg = "${c.base0D}", reversed = true }
      preview = { fg = "${c.base0C}", underline = true }

      [status]
      overall = { fg = "${c.base05}", bg = "${c.base01}" }
      perm_sep = { fg = "${c.base03}" }
      perm_type = { fg = "${c.base0D}" }
      perm_read = { fg = "${c.base0A}" }
      perm_write = { fg = "${c.base08}" }
      perm_exec = { fg = "${c.base0B}" }
      progress_label = { fg = "${c.base06}", bold = true }
      progress_normal = { fg = "${c.base00}", bg = "${c.base0B}" }
      progress_error = { fg = "${c.base00}", bg = "${c.base08}" }

      [which]
      border = { fg = "${c.base08}" }
      mask = { fg = "${c.base03}" }
      cand = { fg = "${c.base0C}", bold = true }
      rest = { fg = "${c.base04}" }
      desc = { fg = "${c.base0E}" }
      separator_style = { fg = "${c.base03}" }

      [confirm]
      border = { fg = "${c.base08}" }
      title = { fg = "${c.base0D}", bold = true }
      body = { fg = "${c.base05}" }
      list = { fg = "${c.base05}" }
      btn_yes = { fg = "${c.base00}", bg = "${c.base0B}", bold = true }
      btn_no = { fg = "${c.base08}", bold = true }

      [spot]
      border = { fg = "${c.base08}" }
      title = { fg = "${c.base0D}", bold = true }
      tbl_col = { fg = "${c.base0D}" }
      tbl_cell = { fg = "${c.base0A}", reversed = true }

      [notify]
      title_info = { fg = "${c.base0B}" }
      title_warn = { fg = "${c.base0A}" }
      title_error = { fg = "${c.base08}" }

      [pick]
      border = { fg = "${c.base08}" }
      active = { fg = "${c.base0A}", bold = true }
      inactive = { fg = "${c.base05}" }

      [input]
      border = { fg = "${c.base08}" }
      title = { fg = "${c.base0D}" }
      value = { fg = "${c.base05}" }
      selected = { fg = "${c.base00}", bg = "${c.base0A}" }

      [cmp]
      border = { fg = "${c.base08}" }
      active = { fg = "${c.base00}", bg = "${c.base0A}" }
      inactive = { fg = "${c.base05}" }

      [tasks]
      border = { fg = "${c.base08}" }
      title = { fg = "${c.base0D}" }
      hovered = { fg = "${c.base0A}", bold = true }

      [help]
      border = { fg = "${c.base08}" }
      chord = { fg = "${c.base0C}" }
      action = { fg = "${c.base05}" }
      hovered = { fg = "${c.base0A}", bold = true }

      [filetype]
      rules = [
        { mime = "**/image/*", fg = "${c.base0A}" },
        { mime = "**/{audio,video}/*", fg = "${c.base0E}" },
        { mime = "**/application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "${c.base08}" },
        { mime = "**/application/{pdf,doc,rtf}", fg = "${c.base0C}" },
        { mime = "vfs/{absent,stale}", fg = "${c.base03}" },
        { url = "*", is = "orphan", bg = "${c.base08}" },
        { url = "*", is = "exec", fg = "${c.base0B}" },
        { url = "*", is = "dummy", bg = "${c.base08}" },
        { url = "*/", is = "dummy", bg = "${c.base08}" },
        { url = "*/", fg = "${c.base0D}" },
      ]

      # Replacing the maps rather than prepending keeps every icon on the
      # palette; the conditions below provide the fallback glyphs.
      [icon]
      globs = []
      dirs = []
      files = []
      exts = [
        { name = "nix", text = "\uf313", fg = "${c.base0D}" },
        { name = "rs", text = "\ue7a8", fg = "${c.base09}" },
        { name = "js", text = "\ue74e", fg = "${c.base0A}" },
        { name = "mjs", text = "\ue74e", fg = "${c.base0A}" },
        { name = "cjs", text = "\ue74e", fg = "${c.base0A}" },
        { name = "ts", text = "\ue628", fg = "${c.base0D}" },
        { name = "tsx", text = "\ue7ba", fg = "${c.base0D}" },
        { name = "jsx", text = "\ue7ba", fg = "${c.base0A}" },
        { name = "py", text = "\ue73c", fg = "${c.base0A}" },
        { name = "lua", text = "\ue620", fg = "${c.base0D}" },
        { name = "go", text = "\ue627", fg = "${c.base0C}" },
        { name = "c", text = "\ue61e", fg = "${c.base0D}" },
        { name = "h", text = "\uf0fd", fg = "${c.base0D}" },
        { name = "cpp", text = "\ue61d", fg = "${c.base0D}" },
        { name = "hpp", text = "\uf0fd", fg = "${c.base0D}" },
        { name = "json", text = "\ue60b", fg = "${c.base0A}" },
        { name = "toml", text = "\ue6b2", fg = "${c.base09}" },
        { name = "yaml", text = "\ue6b2", fg = "${c.base0C}" },
        { name = "yml", text = "\ue6b2", fg = "${c.base0C}" },
        { name = "md", text = "\ue609", fg = "${c.base05}" },
        { name = "sh", text = "\uf489", fg = "${c.base0B}" },
        { name = "bash", text = "\uf489", fg = "${c.base0B}" },
        { name = "zsh", text = "\uf489", fg = "${c.base0B}" },
        { name = "fish", text = "\uf489", fg = "${c.base0B}" },
        { name = "png", text = "\uf1c5", fg = "${c.base0E}" },
        { name = "jpg", text = "\uf1c5", fg = "${c.base0E}" },
        { name = "jpeg", text = "\uf1c5", fg = "${c.base0E}" },
        { name = "gif", text = "\uf1c5", fg = "${c.base0E}" },
        { name = "webp", text = "\uf1c5", fg = "${c.base0E}" },
        { name = "svg", text = "\uf1c5", fg = "${c.base0E}" },
        { name = "mp3", text = "\uf1c7", fg = "${c.base0C}" },
        { name = "flac", text = "\uf1c7", fg = "${c.base0C}" },
        { name = "wav", text = "\uf1c7", fg = "${c.base0C}" },
        { name = "mp4", text = "\uf1c8", fg = "${c.base0C}" },
        { name = "mkv", text = "\uf1c8", fg = "${c.base0C}" },
        { name = "webm", text = "\uf1c8", fg = "${c.base0C}" },
        { name = "zip", text = "\uf410", fg = "${c.base08}" },
        { name = "tar", text = "\uf410", fg = "${c.base08}" },
        { name = "gz", text = "\uf410", fg = "${c.base08}" },
        { name = "xz", text = "\uf410", fg = "${c.base08}" },
        { name = "zst", text = "\uf410", fg = "${c.base08}" },
        { name = "7z", text = "\uf410", fg = "${c.base08}" },
        { name = "pdf", text = "\uf1c1", fg = "${c.base08}" },
        { name = "doc", text = "\uf1c2", fg = "${c.base0D}" },
        { name = "docx", text = "\uf1c2", fg = "${c.base0D}" },
      ]
      conds = [
        { if = "dir", text = "\uf07b", fg = "${c.base0D}" },
        { if = "orphan", text = "\uf127", fg = "${c.base08}" },
        { if = "link", text = "\uf0c1", fg = "${c.base0C}" },
        { if = "exec", text = "\uf120", fg = "${c.base0B}" },
        { if = "hidden", text = "\uf15b", fg = "${c.base04}" },
        { if = "block | char | fifo | sock", text = "\uf15b", fg = "${c.base03}" },
        { if = "!dir", text = "\uf15b", fg = "${c.base05}" },
      ]
    '';
  };
}

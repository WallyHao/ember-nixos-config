{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  stylix = config.lib.stylix.colors;

  # eza accepts 24-bit values as 38;2;R;G;B; the decimal components come from
  # the palette Stylix resolved rather than a second hex parser.
  rgb = key: "38;2;${stylix."${key}-rgb-r"};${stylix."${key}-rgb-g"};${stylix."${key}-rgb-b"}";

  ezaColors = {
    fi = rgb "base05";
    di = rgb "base0D";
    ln = rgb "base0C";
    ex = rgb "base0B";
    or = rgb "base08";
    tw = rgb "base0A";
    su = rgb "base0A";
    sf = rgb "base0A";
    da = rgb "base04";
    uu = rgb "base04";
    un = rgb "base04";
    gu = rgb "base04";
    gn = rgb "base04";
    lc = rgb "base04";
    sn = rgb "base04";
    sb = rgb "base04";
    hd = rgb "base04";
    lp = rgb "base04";
    xx = rgb "base04";
  };
  ezaColorString =
    "reset:" + lib.concatStringsSep ":" (lib.mapAttrsToList (key: value: "${key}=${value}") ezaColors);

  fzfColors = {
    bg = c.base00;
    "bg+" = c.base01;
    fg = c.base05;
    "fg+" = c.base05;
    hl = c.base0B;
    "hl+" = c.base0C;
    info = c.base0B;
    prompt = c.base08;
    pointer = c.base08;
    marker = c.base08;
    spinner = c.base08;
    header = c.base04;
    border = c.base03;
  };
  fzfColorString = lib.concatStringsSep "," (
    lib.mapAttrsToList (key: value: "${key}:${value}") fzfColors
  );

  fzfDefaultOpts = [
    "--height=45%"
    "--layout=reverse"
    "--border=sharp"
    "--info=inline"
    "--prompt='> '"
    "--pointer='>'"
    "--marker='+'"
    "--color=${fzfColorString}"
  ];
in
{
  config = lib.mkIf config.ember.desktop.enable {
    programs.zsh.initContent = ''
      # eza/fzf/fd/zoxide belong to the independent profile. When a command is
      # absent, skip the integration and leave the shell usable; never install
      # packages from shell startup.
      #
      # NixOS /etc/zshrc defines ls/l/ll aliases before this file is parsed.
      # Alias expansion happens while zsh parses the compound `if` below, so
      # the unalias must be its own top-level command, not part of that block.
      unalias l ls la ll lt 2>/dev/null || true
      if command -v eza >/dev/null 2>&1; then
        export EZA_COLORS=${lib.escapeShellArg ezaColorString}
        l() { command eza --tree --group-directories-first -L 1 "$@"; }
        ls() { command eza --tree --group-directories-first --long -L 1 "$@"; }
        la() { command eza --tree --group-directories-first -la -L 1 "$@"; }
        ll() {
          local d=1
          if [[ "$1" == <-> ]]; then d="$1"; shift; fi
          command eza --tree --group-directories-first --long -L "$d" "$@"
        }
        lt() {
          local d=5
          if [[ "$1" == <-> ]]; then d="$1"; shift; fi
          command eza --tree --group-directories-first -L "$d" "$@"
        }
      fi

      if command -v fzf >/dev/null 2>&1; then
        export FZF_DEFAULT_OPTS=${lib.escapeShellArg (lib.concatStringsSep " " fzfDefaultOpts)}
        if command -v fd >/dev/null 2>&1; then
          export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
          export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
          export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
        fi
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh
        source ${pkgs.fzf}/share/fzf/completion.zsh
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
        zstyle ':fzf-tab:*' use-fzf-default-opts yes
        zstyle ':fzf-tab:*' switch-group '[' ']'
        zstyle ':completion:*' menu no
        bindkey '^I' fzf-tab-complete
        bindkey '^[j' fzf-history-widget
        bindkey '^[k' fzf-file-widget
        bindkey '^[l' fzf-cd-widget
      fi
    '';
  };
}

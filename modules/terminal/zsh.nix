{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  state = "${config.home.homeDirectory}/.local/state";

  # Folio's p10k resource clears most POWERLEVEL9K_* options when sourced, so
  # the colour overrides below must stay between it and the theme.
  p10kColors = {
    DIR_FOREGROUND = c.base05;
    DIR_PATH_SEPARATOR_FOREGROUND = c.base04;
    DIR_PATH_HIGHLIGHT_FOREGROUND = c.base08;
    VCS_FOREGROUND = c.base0B;
    VCS_INCOMING_CHANGESFORMAT_FOREGROUND = c.base0C;
    VCS_OUTGOING_CHANGESFORMAT_FOREGROUND = c.base0C;
    TIME_FOREGROUND = c.base04;
    VIRTUALENV_FOREGROUND = c.base0C;
    COMMAND_EXECUTION_TIME_FOREGROUND = c.base0A;
    CONTEXT_FOREGROUND = c.base04;
    CONTEXT_ROOT_TEMPLATE = "%F{${c.base05}}%n%f%F{${c.base04}}@%m%f";
    CONTEXT_TEMPLATE = "%F{${c.base04}}%n@%m%f";
    PROMPT_CHAR_OK_VIINS_FOREGROUND = c.base08;
    PROMPT_CHAR_OK_VICMD_FOREGROUND = c.base08;
    PROMPT_CHAR_OK_VIVIS_FOREGROUND = c.base08;
    PROMPT_CHAR_ERROR_VIINS_FOREGROUND = c.base08;
    PROMPT_CHAR_ERROR_VICMD_FOREGROUND = c.base08;
    PROMPT_CHAR_ERROR_VIVIS_FOREGROUND = c.base08;
  };
  p10kOverrides = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      key: value: "typeset -g POWERLEVEL9K_${key}=${lib.escapeShellArg value}"
    ) p10kColors
  );
in
{
  config = lib.mkIf config.ember.desktop.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        path = "${state}/zsh/history";
        size = 10000;
        save = 10000;
        share = true;
        ignoreAllDups = true;
        saveNoDups = true;
      };

      # ls/ll/la/l/lt are shell functions in terminal/tools.nix. Keep only
      # unrelated aliases here; an alias would expand while the function is
      # parsed and shadow the eza adapter.
      shellAliases = {
        cat = "bat --paging=never";
        grep = "rg";
        find = "fd";
      };

      initContent = ''
        # Keep first startup noninteractive and deterministic.
        source ${./resources/p10k.zsh}
        typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
        typeset -g POWERLEVEL9K_MODE=nerdfont-complete
        ${p10kOverrides}
        source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

        if command -v zoxide >/dev/null 2>&1; then
          eval "$(zoxide init zsh)"
        fi

        if command -v atuin >/dev/null 2>&1; then
          eval "$(atuin init zsh)"
        fi

        y() {
          local tmp cwd result
          if ! command -v yazi >/dev/null 2>&1; then
            print -u2 'Yazi is not installed yet. Run:'
            print -u2 '  just apps'
            return 127
          fi
          tmp="$(mktemp "''${TMPDIR:-/tmp}/ember-yazi-cwd.XXXXXX")" || return
          yazi "$@" --cwd-file="$tmp"
          result=$?
          if [ "$result" -eq 0 ] && cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
          fi
          rm -f -- "$tmp"
          return "$result"
        }
      '';
    };

    home.activation.emberStateDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.local/state/zsh"
      ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.local/share/keyrings"
      ${pkgs.coreutils}/bin/install -d -m 700 "$HOME/.local/state/nvim/undo"
    '';
  };
}

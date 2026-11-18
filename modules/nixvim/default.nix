{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  state = "${config.home.homeDirectory}/.local/state";

  # markdown-preview.nvim serves `mkdp_markdown_css`/`mkdp_highlight_css`
  # instead of its bundled stylesheets, so each file is rebuilt as
  # "upstream CSS + Emberlight overrides": layout keeps tracking the plugin,
  # colours come from the palette.
  paletteCss =
    file:
    pkgs.writeText (baseNameOf file) (
      builtins.replaceStrings (map (key: "@${key}@") (builtins.attrNames c)) (map (key: c.${key}) (
        builtins.attrNames c
      )) (builtins.readFile file)
    );
  previewCss = pkgs.concatText "markdown-preview.css" [
    "${pkgs.vimPlugins.markdown-preview-nvim.src}/app/_static/markdown.css"
    (paletteCss ./resources/markdown-preview.css)
  ];
  previewHighlightCss = pkgs.concatText "highlight.css" [
    "${pkgs.vimPlugins.markdown-preview-nvim.src}/app/_static/highlight.css"
    (paletteCss ./resources/highlight.css)
  ];

  # lualine cannot resolve `theme = "auto"` without a colourscheme plugin, so
  # the palette is passed as an explicit theme table.
  lualineMode = accent: {
    a = {
      fg = c.base00;
      bg = accent;
      gui = "bold";
    };
    b = {
      fg = c.base05;
      bg = c.base01;
    };
    c = {
      fg = c.base04;
      bg = c.base00;
    };
  };
  lualineTheme = {
    normal = lualineMode c.base0D;
    insert = lualineMode c.base0B;
    visual = lualineMode c.base0E;
    replace = lualineMode c.base08;
    command = lualineMode c.base0A;
    terminal = lualineMode c.base0C;
    inactive = {
      a = {
        fg = c.base03;
        bg = c.base01;
      };
      b = {
        fg = c.base03;
        bg = c.base01;
      };
      c = {
        fg = c.base03;
        bg = c.base00;
      };
    };
  };
in
{
  imports = [ inputs.nixvim.homeModules.nixvim ];

  config = lib.mkIf config.ember.desktop.enable {
    programs.nixvim = {
      enable = true;
      nixpkgs.pkgs = pkgs;
      viAlias = true;
      vimAlias = true;

      clipboard = {
        register = "unnamedplus";
        providers.wl-copy.enable = true;
      };

      globals.mapleader = " ";

      plugins.lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          pyright.enable = true;
          ts_ls.enable = true;
        };
      };

      # Browser preview: mermaid/KaTeX assets ship inside the plugin, and the
      # wrapped nvim gets nodejs through the plugin's runtime deps.
      plugins.markdown-preview = {
        enable = true;
        settings = {
          auto_start = 0;
          auto_close = 1;
          echo_preview_url = 1;
          theme = "dark";
          markdown_css = "${previewCss}";
          highlight_css = "${previewHighlightCss}";
          preview_options = {
            disable_sync_scroll = 0;
            sync_scroll_type = "middle";
            disable_filename = 1;
          };
        };
      };

      # Line-number/sign column: gitsigns marks link to the Diff groups below,
      # and `opts.statuscolumn` right-aligns relative numbers.
      plugins.gitsigns.enable = true;

      plugins.lualine = {
        enable = true;
        settings = {
          options = {
            theme = lualineTheme;
            globalstatus = true;
            icons_enabled = true;
            section_separators = {
              left = "";
              right = "";
            };
            component_separators = {
              left = "|";
              right = "|";
            };
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [
              "branch"
              "diff"
            ];
            lualine_c = [ ];
            lualine_x = [
              "diagnostics"
              "filetype"
            ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
          inactive_sections = {
            lualine_c = [ ];
          };
        };
      };

      keymaps = [
        {
          mode = "n";
          key = "<leader>mp";
          action = "<cmd>MarkdownPreviewToggle<cr>";
          options = {
            silent = true;
            desc = "Markdown preview toggle";
          };
        }
        {
          mode = "n";
          key = "<leader>ms";
          action = "<cmd>MarkdownPreviewStop<cr>";
          options = {
            silent = true;
            desc = "Markdown preview stop";
          };
        }
      ];

      opts = {
        number = true;
        relativenumber = true;
        cursorline = true;
        splitright = true;
        splitbelow = true;
        termguicolors = true;
        mouse = "a";
        # One global statusline (lualine `globalstatus`) and a custom status
        # column that right-aligns relative numbers next to the git signs.
        laststatus = 3;
        numberwidth = 3;
        statuscolumn = "%s%=%{v:relnum == 0 ? v:lnum : v:relnum} ";
        undofile = true;
        undodir = "${state}/nvim/undo";
        signcolumn = "yes";
        updatetime = 250;
      };

      highlightOverride = {
        Normal = {
          fg = c.base05;
          bg = c.base00;
        };
        NormalFloat = {
          fg = c.base05;
          bg = c.base01;
        };
        CursorLine = {
          bg = c.base01;
        };
        LineNr = {
          fg = c.base03;
        };
        CursorLineNr = {
          fg = c.base08;
          bold = true;
        };
        Visual = {
          bg = c.base02;
        };
        Search = {
          fg = c.base00;
          bg = c.base0A;
        };
        StatusLine = {
          fg = c.base05;
          bg = c.base01;
        };
        StatusLineNC = {
          fg = c.base03;
          bg = c.base01;
        };
        Pmenu = {
          fg = c.base05;
          bg = c.base01;
        };
        PmenuSel = {
          fg = c.base00;
          bg = c.base0D;
        };
        # gitsigns links its signs to these Diff groups.
        DiffAdd = {
          fg = c.base0B;
        };
        DiffChange = {
          fg = c.base0A;
        };
        DiffDelete = {
          fg = c.base08;
        };
        DiffText = {
          fg = c.base0E;
          bg = c.base01;
        };
        # UI groups that lualine and the status column read while resolving
        # their own colours.
        Comment = {
          fg = c.base04;
        };
        TabLineSel = {
          fg = c.base06;
          bg = c.base02;
        };
        WinSeparator = {
          fg = c.base02;
        };
        DiagnosticError = {
          fg = c.base08;
        };
        DiagnosticWarn = {
          fg = c.base0A;
        };
        DiagnosticInfo = {
          fg = c.base0D;
        };
        DiagnosticHint = {
          fg = c.base0C;
        };
        # gitsigns 2.x links its signs to these Neovim 0.10 groups, before
        # falling back to Diff*.
        Added = {
          fg = c.base0B;
        };
        Changed = {
          fg = c.base0A;
        };
        Removed = {
          fg = c.base08;
        };
      };
    };

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}

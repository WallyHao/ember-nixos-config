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

      opts = {
        number = true;
        relativenumber = true;
        cursorline = true;
        splitright = true;
        splitbelow = true;
        termguicolors = true;
        mouse = "a";
        laststatus = 2;
        statusline = "%f %m %= %l:%c";
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
      };
    };

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}

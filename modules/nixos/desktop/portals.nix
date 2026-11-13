{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    fonts.packages = [
      (import ../../../packages/lxgw-wenkai-gb.nix { inherit pkgs; })
      pkgs.nerd-fonts.symbols-only
      pkgs.dejavu_fonts
    ];

    environment.systemPackages = [
      pkgs.wl-clipboard
    ];

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-gnome
      ];
      config.niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Access" = "gtk";
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
        "org.freedesktop.impl.portal.Notification" = "gtk";
        "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      };
    };
  };

}

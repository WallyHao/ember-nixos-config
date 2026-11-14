# nmtui and other newt frontends read their widget palette from NEWT_COLORS.
# This applies the Emberlight scheme to every newt TUI in the system.
{ config, lib, ... }:
let
  c = config.lib.stylix.colors.withHashtag;

  palette = [
    "root=${c.base05},${c.base00}"
    "border=${c.base08},${c.base00}"
    "window=${c.base05},${c.base01}"
    "shadow=${c.base00},${c.base00}"
    "title=${c.base0A},${c.base02}"
    "button=${c.base05},${c.base02}"
    "actbutton=${c.base00},${c.base0A}"
    "checkbox=${c.base05},${c.base01}"
    "actcheckbox=${c.base00},${c.base0A}"
    "entry=${c.base05},${c.base02}"
    "label=${c.base05},${c.base00}"
    "listbox=${c.base05},${c.base01}"
    "actlistbox=${c.base00},${c.base0A}"
    "textbox=${c.base05},${c.base01}"
    "acttextbox=${c.base00},${c.base0A}"
    "helpline=${c.base04},${c.base00}"
    "roottext=${c.base05},${c.base00}"
    "emptyscale=${c.base02},${c.base02}"
    "fullscale=${c.base0B},${c.base0B}"
    "disentry=${c.base03},${c.base01}"
    "compactbutton=${c.base05},${c.base02}"
    "sellistbox=${c.base05},${c.base02}"
    "actsellistbox=${c.base00},${c.base0A}"
  ];
in
{
  environment.variables.NEWT_COLORS = lib.concatStringsSep ":" palette;
}

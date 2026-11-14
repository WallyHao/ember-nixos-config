# Folio appearance resources

input-language.c is copied from repos/folio-nixos-config/modules/input/runtime/observers/language.c,
with its upstream provenance header preserved. The independent observer does not import the Folio
manager. It supplies Waybar JSON and owns a StatusNotifierWatcher name; the matching bar intentionally
has no tray module. Fonts are packaged independently in packages/lxgw-wenkai-gb.nix.

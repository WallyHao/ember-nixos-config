{ config, ... }:
let
  c = config.ember.appearance.colors;
in
{
  programs.btop = {
    enable = true;
    # btop is installed by the independent software profile; Home Manager only
    # owns its configuration.
    package = null;

    settings = {
      color_theme = "emberlight";
      theme_background = true;
      truecolor = true;
    };

    themes.emberlight = ''
      theme[main_bg]="${c.base00}"
      theme[main_fg]="${c.base05}"
      theme[title]="${c.base06}"
      theme[hi_fg]="${c.base0D}"
      theme[selected_bg]="${c.base02}"
      theme[selected_fg]="${c.base07}"
      theme[inactive_fg]="${c.base03}"
      theme[graph_text]="${c.base04}"
      theme[meter_bg]="${c.base02}"
      theme[proc_misc]="${c.base0C}"
      theme[cpu_box]="${c.base08}"
      theme[mem_box]="${c.base08}"
      theme[net_box]="${c.base08}"
      theme[proc_box]="${c.base08}"
      theme[div_line]="${c.base03}"
      theme[temp_start]="${c.base0B}"
      theme[temp_mid]="${c.base0A}"
      theme[temp_end]="${c.base08}"
      theme[cpu_start]="${c.base0D}"
      theme[cpu_mid]="${c.base0C}"
      theme[cpu_end]="${c.base0B}"
      theme[free_start]="${c.base0B}"
      theme[free_mid]="${c.base0C}"
      theme[free_end]="${c.base0D}"
      theme[cached_start]="${c.base0E}"
      theme[cached_mid]="${c.base0D}"
      theme[cached_end]="${c.base0C}"
      theme[available_start]="${c.base0C}"
      theme[available_mid]="${c.base0D}"
      theme[available_end]="${c.base0E}"
      theme[used_start]="${c.base0A}"
      theme[used_mid]="${c.base09}"
      theme[used_end]="${c.base08}"
      theme[download_start]="${c.base0D}"
      theme[download_mid]="${c.base0C}"
      theme[download_end]="${c.base0B}"
      theme[upload_start]="${c.base0E}"
      theme[upload_mid]="${c.base0D}"
      theme[upload_end]="${c.base0C}"
      theme[process_start]="${c.base0B}"
      theme[process_mid]="${c.base0C}"
      theme[process_end]="${c.base0D}"
    '';
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.ember.appearance.colors;
  panelSvg = pkgs.writeText "ember-input-panel.svg" ''
    <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">
      <rect x="3" y="3" width="74" height="74" rx="12" ry="12" fill="${c.base00}"/>
      <rect x="3" y="3" width="74" height="74" rx="12" ry="12" fill="none" stroke="${c.base08}" stroke-width="2"/>
    </svg>
  '';
  panel = pkgs.runCommand "ember-input-panel.png" {
    nativeBuildInputs = [ pkgs.librsvg ];
  } "rsvg-convert -w 80 -h 80 ${panelSvg} -o $out";
in
{
  config = lib.mkIf config.ember.desktop.enable {
    xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text =
      "[Desktop Entry]\nType=Application\nName=Fcitx 5\nHidden=true\n";
    xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
      patch:
        __include: rime_ice_suggestion:/
        schema_list:
          - schema: rime_ice
        menu/page_size: 7
    '';
    xdg.configFile."fcitx5/conf/classicui.conf".text = ''
      Theme=emberlight
      Font=LXGW WenKai Mono GB 18
      Vertical Candidate List=False
      PreferTextIcon=False
    '';
    xdg.dataFile."fcitx5/themes/emberlight/panel.png".source = panel;
    xdg.dataFile."fcitx5/themes/emberlight/theme.conf".text = ''
      [Metadata]
      Name=Emberlight
      Version=1
      Description=Emberlight candidate panel
      [InputPanel]
      NormalColor=${c.base05}
      HighlightCandidateColor=${c.base0A}
      HighlightColor=${c.base0A}
      HighlightBackgroundColor=#00000000
      FullWidthHighlight=False
      [InputPanel/Background]
      Image=panel.png
      Color=#00000000
      BorderColor=#ffffff00
      BorderWidth=0
      [InputPanel/Background/Margin]
      Left=18
      Right=18
      Top=18
      Bottom=18
      [InputPanel/Highlight]
      Image=
      Color=#00000000
      BorderColor=#ffffff00
      BorderWidth=0
      [InputPanel/ContentMargin]
      Left=8
      Right=8
      Top=6
      Bottom=6
      [InputPanel/TextMargin]
      Left=6
      Right=6
      Top=4
      Bottom=4
      [InputPanel/PrevPage]
      Image=
      [InputPanel/NextPage]
      Image=
      [InputPanel/ShadowMargin]
      Left=0
      Right=0
      Top=0
      Bottom=0
    '';
  };
}

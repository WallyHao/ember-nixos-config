{
  inputs,
  inventory,
  deployment,
}:
let
  lib = inputs.nixpkgs.lib;
  mkHost = import ../../lib/mk-host.nix;

  preview = mkHost {
    inherit inputs inventory;
    hostName = "ember";
    hardwareModule = inventory.hosts.ember.physicalHardwareModule;
    storageModule = ../fixtures/storage.nix;
  };

  cfg = preview.system.config;
  hm = cfg.home-manager.users.wallyhao;
  niri = hm.wayland.windowManager.niri;
  foot = hm.programs.foot;
  zsh = hm.programs.zsh;
  pam = cfg.security.pam.services.greetd.rules;
  stylixColors = hm.lib.stylix.colors;
  hmColors = hm.ember.appearance.colors;
  classicui = hm.xdg.configFile."fcitx5/conf/classicui.conf".text;
  fcitxTheme = hm.xdg.dataFile."fcitx5/themes/emberlight/theme.conf".text;
  rimePatch = hm.xdg.dataFile."fcitx5/rime/default.custom.yaml".text;

  packageOf = name: builtins.any (p: (p.pname or "") == name) hm.home.packages;
  bind = key: niri.settings.binds.${key} or { };
  spawnHas = key: action: (bind key).spawn or [ ] == action;

  sourcePalette = (builtins.fromJSON (builtins.readFile ../../assets/themes/emberlight.json)).palette;
  checks = {
    palette-complete =
      builtins.length (builtins.attrNames sourcePalette) == 16
      && builtins.all (key: hmColors.${key} == lib.toLower sourcePalette.${key}) (
        builtins.attrNames sourcePalette
      );
    system-identity = cfg.networking.hostName == "ember";
    hm-identity =
      hm.home.username == "wallyhao"
      && hm.home.homeDirectory == "/home/wallyhao"
      && hm.home.stateVersion == "26.11";
    hm-integration = cfg.home-manager.useGlobalPkgs && cfg.home-manager.useUserPackages;
    graphical-default =
      cfg.ember.desktop.enable
      && cfg.systemd.defaultUnit == "graphical.target"
      && cfg.services.getty.autologinUser == null
      && !(cfg.services.greetd.settings ? initial_session)
      && cfg.systemd.services."getty@tty2".enable;
    greetd =
      let
        command = cfg.services.greetd.settings.default_session.command;
      in
      cfg.services.greetd.enable
      && cfg.services.greetd.useTextGreeter
      && cfg.systemd.services.greetd.restartIfChanged == false
      # Multiline artwork belongs in the wrapper, never in greetd's TOML.
      && builtins.match "/nix/store/[^/]+-ember-greeter" command != null
      && !(lib.hasInfix "\n" command)
      && cfg.console.font == "ter-v32n";
    niri =
      cfg.programs.niri.enable
      && !cfg.programs.niri.useNautilus
      && niri.enable
      && niri.checkConfig
      && niri.systemd.enable
      && niri.xwaylandSatellitePackage == null
      && niri.portalPackage == null
      && niri.settings.layout.gaps == 16
      && niri.settings.layout.focus-ring.width == 3
      &&
        niri.settings.layout.struts == {
          top = -12;
          bottom = 0;
          left = 0;
          right = 0;
        }
      && (builtins.head niri.settings.window-rule._children).geometry-corner-radius == 0
      && builtins.length niri.settings.window-rule._children == 1;
    keybindings =
      spawnHas "Super+Return" [ "foot" ]
      && spawnHas "Super+D" [ "fuzzel" ]
      && spawnHas "Super+V" [ "ember-clipboard" ]
      && spawnHas "Super+C" [ "ember-control" ]
      && spawnHas "Super+P" [ "ember-control" ]
      && spawnHas "Super+Y" [
        "foot"
        "-e"
        "ember-yazi"
      ]
      && spawnHas "Super+Shift+R" [
        "ember-session"
        "reboot"
      ]
      && spawnHas "Super+Shift+T" [
        "ember-session"
        "poweroff"
      ]
      && ((bind "Super+Q") ? close-window)
      && spawnHas "Super+Shift+E" [
        "ember-session"
        "logout"
      ]
      && ((bind "Super+Tab") ? toggle-overview)
      && ((bind "Super+Shift+Slash") ? show-hotkey-overlay)
      && ((bind "Super+F") ? fullscreen-window)
      && ((bind "Super+G") ? center-column)
      && ((bind "Super+S") ? screenshot-screen)
      && ((bind "Super+Shift+S") ? screenshot)
      && ((bind "Super+Left") ? focus-column-left)
      && ((bind "Super+Right") ? focus-column-right)
      && ((bind "Super+Up") ? focus-window-up)
      && ((bind "Super+Down") ? focus-window-down)
      && ((bind "Super+Shift+Left") ? move-column-left)
      && ((bind "Super+Shift+Right") ? move-column-right)
      && ((bind "Super+1") ? focus-workspace)
      && ((bind "Super+0") ? focus-workspace)
      && ((bind "Super+Shift+1") ? move-window-to-workspace)
      && ((bind "Super+Shift+0") ? move-window-to-workspace)
      && ((bind "XF86AudioRaiseVolume") ? spawn)
      && ((bind "XF86AudioLowerVolume") ? spawn)
      && ((bind "XF86AudioMute") ? spawn)
      && ((bind "XF86MonBrightnessUp") ? spawn)
      && ((bind "XF86MonBrightnessDown") ? spawn)
      && !((bind "Super+W") ? spawn)
      && !((bind "Super+N") ? spawn)
      && !((bind "Super+A") ? spawn)
      && !((bind "Super+Shift+Tab") ? spawn);
    independent-desktop =
      !hm.programs.noctalia.enable
      && hm.programs.waybar.enable
      && hm.programs.waybar.settings.main.height == 36
      && hm.programs.waybar.settings.main.modules-left == [ "niri/workspaces" ]
      &&
        hm.programs.waybar.settings.main.modules-right == [
          "custom/input-language"
          "clock#date"
          "clock#time"
        ]
      && hm.programs.fuzzel.enable
      && hm.programs.fuzzel.settings.main.width == 40
      && hm.programs.fuzzel.settings.main.font == "LXGW WenKai Mono GB:size=18"
      && hm.services.mako.enable
      && hm.services.mako.settings.max-history == 0
      && hm.services.mako.settings.border-radius == 0
      && hm.systemd.user.services ? ember-polkit
      && hm.systemd.user.services ? ember-clipboard-watch
      && hm.systemd.user.services ? ember-wallpaper
      && hm.programs.swaylock.enable
      && hm.services.swayidle.enable
      && cfg.security.pam.services ? swaylock;
    stylix =
      cfg.stylix.enable
      && !cfg.stylix.autoEnable
      && cfg.stylix.polarity == "dark"
      && cfg.stylix.image == null
      && cfg.stylix.base16Scheme.base00 == "#120B13"
      && builtins.elem "b85753" cfg.console.colors
      && hm.stylix.enable
      && !hm.stylix.autoEnable
      && hm.stylix.targets.foot.enable
      && !hm.stylix.targets.foot.fonts.enable
      && !hm.stylix.targets.fzf.enable
      && !hm.stylix.targets.fcitx5.enable
      && !hm.stylix.targets.nixvim.enable
      && hmColors.base00 == stylixColors.withHashtag.base00
      && hmColors.base08 == stylixColors.withHashtag.base08
      && hm.ember.appearance.name == stylixColors.scheme;
    foot =
      foot.enable
      && !foot.server.enable
      && foot.settings.main.font == "LXGW WenKai Mono GB:size=18"
      && foot.settings.main.pad == "15x15"
      && foot.settings.main.initial-color-theme == "dark"
      && foot.settings.colors-dark.alpha == 1.0
      && foot.settings.colors-dark.background == stylixColors.base00
      && foot.settings.colors-dark.foreground == stylixColors.base05
      && foot.settings.colors-dark.regular1 == stylixColors.base08
      && foot.settings.colors-dark.bright7 == stylixColors.base07
      && foot.settings.cursor.style == "block"
      && foot.settings.cursor.blink == "no";
    shell =
      let
        init = zsh.initContent;
      in
      zsh.enable
      && zsh.enableCompletion
      && zsh.autosuggestion.enable
      && zsh.syntaxHighlighting.enable
      && zsh.history.path == "/home/wallyhao/.local/state/zsh/history"
      && zsh.plugins == [ ]
      && !(zsh.shellAliases ? ls)
      && !(zsh.shellAliases ? ll)
      && !(zsh.shellAliases ? la)
      && lib.hasInfix "p10k.zsh" init
      && lib.hasInfix "zsh-powerlevel10k/powerlevel10k.zsh-theme" init
      && lib.hasInfix "POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true" init
      && lib.hasInfix "POWERLEVEL9K_INSTANT_PROMPT=quiet" init
      && lib.hasInfix "EZA_COLORS='reset:" init
      && lib.hasInfix "eza --tree --group-directories-first" init
      && lib.hasInfix "--height=45% --layout=reverse --border=sharp --info=inline" init
      && lib.hasInfix "fzf-tab.plugin.zsh" init
      && lib.hasInfix "bindkey '^[j' fzf-history-widget" init;
    input-method =
      lib.hasInfix "Theme=emberlight" classicui
      && lib.hasInfix "Font=LXGW WenKai Mono GB 18" classicui
      && lib.hasInfix "Vertical Candidate List=False" classicui
      && lib.hasInfix "menu/page_size: 7" rimePatch
      && lib.hasInfix "NormalColor=${hmColors.base05}" fcitxTheme
      && lib.hasInfix "HighlightCandidateColor=${hmColors.base0A}" fcitxTheme
      && lib.hasInfix "Left=8" fcitxTheme
      && lib.hasInfix "Top=6" fcitxTheme
      && lib.hasInfix "Image=panel.png" fcitxTheme
      && hm.xdg.dataFile ? "fcitx5/themes/emberlight/panel.png";
    nixvim =
      hm.programs.nixvim.enable
      && hm.programs.nixvim.viAlias
      && hm.programs.nixvim.vimAlias
      && hm.home.sessionVariables.EDITOR == "nvim";
    profile-path =
      builtins.elem "/home/wallyhao/.local/state/nix/profiles/profile/bin" hm.home.sessionPath
      && builtins.match ".*profiles/profile/share.*" hm.home.sessionVariables.XDG_DATA_DIRS != null;
    yazi-not-duplicated = !(packageOf "yazi");
    keyring =
      cfg.services.gnome.gnome-keyring.enable
      && pam.auth ? gnome_keyring
      && pam.password ? gnome_keyring
      && pam.session ? gnome_keyring;
    audio =
      cfg.services.pipewire.enable
      && cfg.services.pipewire.audio.enable
      && cfg.services.pipewire.pulse.enable
      && cfg.services.pipewire.wireplumber.enable
      && !cfg.services.pulseaudio.enable;
    portals =
      cfg.xdg.portal.enable
      && cfg.xdg.portal.config.niri."org.freedesktop.impl.portal.FileChooser" == "gtk"
      && builtins.any (p: p.pname or "" == "xdg-desktop-portal-gtk") cfg.xdg.portal.extraPortals;
    power-exclusive =
      cfg.services.tlp.enable
      && !cfg.services.power-profiles-daemon.enable
      && !cfg.services.auto-cpufreq.enable
      && !cfg.services.tuned.enable;
    storage-bound = deployment.storageBound && deployment.installable;
    preview-virtual-disk = cfg.disko.devices.disk.main.device == "/dev/vda";
  };

  failed = builtins.filter (name: checks.${name} != true) (builtins.attrNames checks);
in
if failed != [ ] then
  throw "ember user-environment contracts failed: ${builtins.concatStringsSep ", " failed}"
else
  checks

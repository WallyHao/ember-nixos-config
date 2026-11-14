{
  config,
  lib,
  pkgs,
  ...
}:
let
  keyringModule = "${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so";
  greetdRules = config.security.pam.services.greetd.rules;

  # Keep Folio's quiet, centred TTY login, using Stylix ANSI colours. Match
  # the border to the black background so the form has no visible frame.
  # A real console font controls glyph size; Foot's font cannot affect tty1.
  # Fastfetch's MIT-licensed ASCII artwork, stored locally. Pad *before*
  # adding ANSI colours: centering each ragged row distorts the snowflake.
  logoLines = lib.splitString "\n" (
    lib.removeSuffix "\n" (builtins.readFile ../appearance/resources/nixos-logo.txt)
  );
  stripColors = lib.replaceStrings [ "$1" "$2" ] [ "" "" ];
  logoWidth = lib.foldl' lib.max 0 (map (line: builtins.stringLength (stripColors line)) logoLines);
  login = config.ember.appearance.login;
  renderLogoLine =
    line:
    lib.replaceStrings [ "$1" "$2" ] [ login.logoPrimary login.logoSecondary ] (
      line + lib.concatStrings (lib.replicate (logoWidth - builtins.stringLength (stripColors line)) " ")
    )
    + login.reset;
  greeting = lib.concatStringsSep "\n" (
    map renderLogoLine logoLines
    ++ [
      ""
      (lib.toUpper config.lib.stylix.colors.scheme)
    ]
  );
  tuigreetArgs = [
    "${pkgs.tuigreet}/bin/tuigreet"
    "--no-config"
    # A narrower centred form brings both prompts inward by 8 columns.
    # The 32-column logo still fits within the 40-column content area.
    "--width"
    "44"
    "--container-padding"
    "2"
    "--prompt-padding"
    "1"
    "--asterisks"
    "--greeting"
    greeting
    "--greet-align"
    "center"
    "--time"
    "--remember"
    "--theme"
    login.theme
    "--cmd"
    "niri-session"
  ];
  # greetd 0.10.3 cannot parse the multiline literal TOML emitted when the
  # logo is embedded in default_session.command. Keep its config single-line;
  # Bash handles the quoted, multiline greeting inside this store script.
  greeter = pkgs.writeShellScript "ember-greeter" ''
    exec ${lib.escapeShellArgs tuigreetArgs}
  '';
in
{
  config = lib.mkIf config.ember.desktop.enable {
    # 16x32 glyphs instead of the tiny default 8x16 console face.
    console = {
      packages = [ pkgs.terminus_font ];
      font = "ter-v32n";
    };

    programs.niri = {
      enable = true;
      useNautilus = false;
    };

    services.gnome.gnome-keyring.enable = true;

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings = {
        default_session = {
          command = "${greeter}";
        };
      };
    };

    # Applying a new login layout must not interrupt the running desktop.
    # The next normal logout/login (or boot) shows the updated greeter.
    systemd.services.greetd.restartIfChanged = false;

    # greetd owns tty1. Keep tty2 as a password-protected rescue console.
    systemd.services."getty@tty2" = {
      enable = true;
      wantedBy = [ "getty.target" ];
    };

    # greetd's PAM stack deliberately does not use the default rules. Add the
    # keyring hooks explicitly so the Login keyring is unlocked by the same
    # password that authenticates the session.
    security.pam.services.greetd.rules.auth.gnome_keyring = {
      control = "optional";
      modulePath = keyringModule;
      settings.use_authtok = true;
      order = greetdRules.auth.login.order + 10;
    };
    security.pam.services.greetd.rules.password.gnome_keyring = {
      control = "optional";
      modulePath = keyringModule;
      settings.use_authtok = true;
      order = greetdRules.password.login.order + 10;
    };
    security.pam.services.greetd.rules.session.gnome_keyring = {
      control = "optional";
      modulePath = keyringModule;
      settings.auto_start = true;
      order = greetdRules.session.login.order + 10;
    };

    # Keep normal password changes and the keyring in sync for the account
    # regression path and for future local logins.
    security.pam.services.login.enableGnomeKeyring = true;
    security.pam.services.passwd.enableGnomeKeyring = true;

    assertions = [
      {
        assertion = !(config.services.greetd.settings ? initial_session);
        message = "greetd must not auto-login; the graphical session requires the account password.";
      }
      {
        assertion = config.services.getty.autologinUser == null;
        message = "No TTY may auto-login.";
      }
      {
        assertion =
          !(config.services.displayManager ? regreet && config.services.displayManager.regreet.enable);
        message = "Do not add a second display manager beside greetd.";
      }
    ];
  };

}

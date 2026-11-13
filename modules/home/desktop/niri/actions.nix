{
  lib,
  ...
}:
{
  options.ember.desktop.actions =
    lib.genAttrs
      [
        "launcher"
        "clipboard"
        "controlCenter"
        "session"
        "terminal"
        "fileManager"
        "volumeUp"
        "volumeDown"
        "volumeMute"
        "brightnessUp"
        "brightnessDown"
      ]
      (
        name:
        lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default =
            {
              launcher = [ "fuzzel" ];
              clipboard = [ "ember-clipboard" ];
              controlCenter = [ "ember-control" ];
              session = [ "ember-session" ];
              terminal = [ "foot" ];
              fileManager = [
                "foot"
                "-e"
                "ember-yazi"
              ];
              volumeUp = [
                "ember-volume"
                "up"
              ];
              volumeDown = [
                "ember-volume"
                "down"
              ];
              volumeMute = [
                "ember-volume"
                "mute"
              ];
              brightnessUp = [
                "ember-brightness"
                "up"
              ];
              brightnessDown = [
                "ember-brightness"
                "down"
              ];
            }
            .${name};
          description = "Desktop action backend for ${name}.";
        }
      );
}

{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.ember.desktop.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      audio.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
      socketActivation = true;
      wireplumber.enable = true;
    };

    assertions = [
      {
        assertion = !config.services.pulseaudio.enable;
        message = "PipeWire is the only audio server; do not start PulseAudio.";
      }
    ];
  };

}

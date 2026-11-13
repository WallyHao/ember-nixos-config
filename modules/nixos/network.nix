{ pkgs, ... }:
{
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  # Reuse only connection DATA from Folio; retain Ember's resolved/NM policy. TLP keeps
  # ownership of the laptop's explicit AC/BAT power policy.
  networking.networkmanager.wifi = {
    backend = "wpa_supplicant";
    powersave = false;
  };
  # nmcli is supplied by NetworkManager; nmtui is its low-overhead TUI.
  environment.systemPackages = [ pkgs.networkmanager ];
  services.resolved.enable = true;

  networking.useNetworkd = false;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ ];
  networking.firewall.allowedUDPPorts = [ ];

  services.timesyncd.enable = true;

  boot.supportedFilesystems = [
    "ntfs"
    "exfat"
  ];
}

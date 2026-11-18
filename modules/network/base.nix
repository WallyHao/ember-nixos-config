{ pkgs, ... }:
{
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  # Reuse only connection DATA from Folio; retain Ember's resolved/NM policy. TLP keeps
  # ownership of the laptop's explicit AC/BAT power policy.
  networking.networkmanager.wifi.backend = "wpa_supplicant";
  # TLP owns the AC/BAT Wi-Fi power policy (WIFI_PWR_ON_BAT=on). NM must not
  # override it: wifi.powersave=1 means "ignore", leaving TLP in control
  # instead of the previous hard-coded powersave=false.
  environment.etc."NetworkManager/conf.d/10-wifi-powersave.conf".text = ''
    [connection]
    wifi.powersave=1
  '';
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

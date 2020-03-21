{
  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      address=/localhost/127.0.0.1
      listen-address=127.0.0.1
    '';
  };
}

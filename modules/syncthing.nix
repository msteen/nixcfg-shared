{ config, lib, ... }:

with lib;

let
  cfg = config.services.syncthing;

in {
  options.services.syncthing = with types; {
    domain = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        The forward proxy domain to access the GUI address.
      '';
    };
  };

  config = mkIf (config.services.nginx.enable && cfg.enable && cfg.domain != null) {
    services.nginx.https.${cfg.domain} = ''
      allow 192.168.0.0/24;
      deny all;
      location / {
        ${proxyWithoutHost "http://${cfg.guiAddress}"}
        proxy_set_header Host localhost;
        ${noIndex}
      }
    '';
  };
}

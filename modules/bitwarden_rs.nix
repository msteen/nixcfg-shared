{ config, lib, ... }:

with lib;

let
  cfg = config.services.bitwarden_rs;
  rocketPort = cfg.config.rocketPort or 8000;
  websocketPort = cfg.config.websocketPort or 3012;

in {
  config = mkIf (config.services.nginx.enable && cfg.enable && cfg.config ? domain && hasPrefix "https://" cfg.config.domain) {
    services.nginx.https.${removePrefix "https://" cfg.config.domain} = ''
      include /run/nginx-nixcfg/shared/noindex.conf;
      location / {
        include /run/nginx-nixcfg/shared/proxy.conf;
        proxy_pass http://127.0.0.1:${toString rocketPort};
      }
      location /notifications/hub {
        include /run/nginx-nixcfg/shared/proxy-websocket.conf;
        proxy_pass http://127.0.0.1:${toString websocketPort};
      }
      location /notifications/hub/negotiate {
        include /run/nginx-nixcfg/shared/proxy.conf;
        proxy_pass http://127.0.0.1:${toString rocketPort};
      }
    '';
  };
}

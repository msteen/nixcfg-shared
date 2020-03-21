{ config, ... }:

with import ../lib;

let
  cfg = config.services.nginx;

in {
  options = with types; {
    services.nginx = {
      openPorts = mkOption {
        type = bool;
        default = false;
        description = ''
          Open the default ports used by Nginx for HTTP (80) and HTTPS (443) in the firewall.
        '';
      };

      http = mkOption {
        type = attrsOf lines;
        default = {};
        description = ''
          The server config for HTTP domains.
        '';
      };

      https = mkOption {
        type = attrsOf lines;
        default = {};
        description = ''
          The server config for HTTPS domains.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openPorts [ 80 443 ];

    users.users.dehydrated = { name = cfg.user; group = cfg.group; };
    users.groups.dehydrated = { name = cfg.group; };

    services.dehydrated.domains = genAttrs (attrNames cfg.https) (const []);

    services.nginx.httpConfig = concatStrings (
      mapAttrsToList (domain: serverConfig: optionalString (serverConfig != "" || (cfg.https.${domain} or "") != "") ''
        server {
          listen 80;
          server_name ${domain};
          include /run/nginx-nixcfg/shared/drop.conf;
          ${optionalString ((cfg.https.${domain} or "") != "") ''
            # Redirect HTTP to HTTPS.
            location / {
              return 301 https://$host$request_uri;
            }
          '' + serverConfig}
        }
      '') cfg.http ++
      mapAttrsToList (domain: serverConfig: optionalString (serverConfig != "") ''
        server {
          include /run/nginx-nixcfg/shared/ssl.conf;
          ssl_certificate /var/lib/dehydrated/certs/${domain}/fullchain.pem;
          ssl_certificate_key /var/lib/dehydrated/certs/${domain}/privkey.pem;
          server_name ${domain};
          include /run/nginx-nixcfg/shared/drop.conf;
          ${serverConfig}
        }
      '') cfg.https
    );

    system.activationScripts.nginx-nixcfg = stringAfter [ "users" "groups" ] ''
      mkdir -p /run/nginx-nixcfg
      ln -sfT ${config.path ../config/nginx} /run/nginx-nixcfg/shared
    '';
  };
}

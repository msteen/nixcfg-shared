{ config, pkgs, ... }:

with import ../lib;

let
  version = "0.6.5";

  cfg = config.services.dehydrated;
  domains = concatLists (mapAttrsToList (domain: subdomains: [ domain ] ++ subdomains) cfg.domains);

  user = config.users.users.dehydrated.name;
  group = config.users.groups.dehydrated.name;

  configSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/lukas2511/dehydrated/v${version}/docs/examples/config";
    sha256 = "0sbn05407izi81afhl92nmjhafiy6w5zqf7y319fhiiig9ndfzhy";
  };
  removeUnderscores = replaceStrings [ "_" ] [ "" ];
  valuesToAttrs = f: values: listToAttrs (map (value: nameValuePair (f value) value) values);
  names = concatMap (line:
    let m = builtins.match "#([A-Z_]+)=.*" line; in if m != null then m else []
  ) (splitString "\n" (removeSuffix "\n" (readFile configSrc)));
  nameMap = valuesToAttrs removeUnderscores names
    // valuesToAttrs (name: removeUnderscores name + "IR") (filter (hasSuffix "_D") names);

  nameLookup = name: nameMap.${removeUnderscores (toUpper name)} or (throw "unknown dehydrated config name '${name}'");

  boolToNoYes = bool: if bool then "yes" else "no";

  configEnv = listToAttrs (concatLists (mapAttrsToList (name: value:
    if value != null then [ (nameValuePair (nameLookup name) (if isBool value then boolToNoYes value else toString value)) ] else []
  ) cfg.config));

  configFile = pkgs.writeText "dehydrated.env" (concatStrings (mapAttrsToList (name: value: "${name}=${value}\n") configEnv));

in {
  options.services.dehydrated = with types; {
    domains = mkOption {
      type = attrsOf (listOf str);
      default = {};
      description = ''
        The domains and the corresponding list of subdomains for which a SSL cerficates should be signed.
      '';
    };

    config = mkOption {
      type = attrsOf (nullOr (either (either bool int) str));
      default = {};
      example = literalExample ''
        {
          contactEmail = "contact@example.com";
        }
      '';
      description = ''
        The configuration of dehydrated is done through environment variables,
        however due to the inconsistent use of underscores,
        it is not possible to simply convert names from camel case style to upper case snake case,
        so to support camel case names (e.g. contactEmail) a mapping is created to the actual name.
        The mapping goes from the actual name with underscores removed to the actual name.
        With the exception for actual names ending with _D, they will have additional mapping,
        to cover the more common spelling of _DIR.
        To lookup the actual name, the name is first converted to upper case with its underscores removed.
        Here are a few examples:
        baseDir = BASEDIR
        contactEmail = CONTACT_EMAIL
        configDir = CONFIG_D

        When a null value is assigned to a name, that name will be removed from the config file.
        When a boolean value is assigned to a name, it will replaced by a string containing no/yes for false/true respectively.

        The available configuration options can be found in
        <link xlink:href="https://github.com/lukas2511/dehydrated/blob/v${version}/docs/examples/config">the example file</link>.
      '';
    };
  };

  config = mkIf (cfg.domains != {}) (mkMerge [
    {
      services.dehydrated.config = {
        basedir = "/var/lib/dehydrated";
        wellKnown = "/var/www/dehydrated";
        domainsTxt = "${pkgs.writeText "domains.txt" (concatStrings (mapAttrsToList (domain: subdomains: ''
          ${domain} ${toString subdomains}
        '') cfg.domains))}";
      };

      users.users.dehydrated = { inherit group; };
      users.groups.dehydrated = { };

      systemd.services.dehydrated-well-known = mkIf (configEnv.WELLKNOWN == "/var/www/dehydrated") {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /var/www/dehydrated
          chown ${user}:${group} /var/www/dehydrated
        '';
      };

      systemd.services.dehydrated = {
        description = "Renew Let's Encrypt certificates";
        path = with pkgs; [ dehydrated ];
        serviceConfig = {
          Type = "oneshot";
          User = user;
          Group = group;
          StateDirectory = "dehydrated";
        };
        script = ''
          dehydrated --config ${configFile} --register --accept-terms
          dehydrated --config ${configFile} --cron
        '';
        requires = [ "dehydrated-well-known.service" ];
        after = [ "dehydrated-well-known.service" ];
        wantedBy = [ "multi-user.target" ];
      };

      systemd.timers.dehydrated = {
        description = "Renew Let's Encrypt certificates on time";
        timerConfig = {
          OnCalendar = "02:00";
          Persistent = "true";
          Unit = "dehydrated.service";
        };
        wantedBy = [ "multi-user.target" ];
      };
    }
    (mkIf config.services.nginx.enable {
      systemd.services.dehydrated = {
        requires = [ "nginx.service" ];
        after = [ "nginx.service" ];
      };

      systemd.services.dehydrated-dirs = {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = user;
          Group = group;
          StateDirectory = "dehydrated";
        };
        script = ''
          dir=/var/lib/dehydrated/certs
          if [[ ! -d $dir ]]; then mkdir $dir; chmod 700 $dir; fi
          for domain in ${toString (attrNames cfg.domains)}; do
            dir=/var/lib/dehydrated/certs/$domain
            if [[ ! -d $dir ]]; then mkdir $dir; chmod 700 $dir; fi
          done
        '';
      };

      systemd.services.dehydrated-self-signed-certs = {
        path = with pkgs; [ openssl ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for domain in ${toString (attrNames cfg.domains)}; do
            dir=/var/lib/dehydrated/certs/$domain
            if [[ ! -e $dir/privkey.pem || ! -e $dir/fullchain.pem ]]; then
              openssl req -x509 -newkey rsa:4096 -nodes -days 365 -subj "/CN=$domain" \
                -keyout $dir/privkey.pem -out $dir/fullchain.pem
              chmod 600 $dir/privkey.pem $dir/fullchain.pem
              chown ${user}:${group} $dir/privkey.pem $dir/fullchain.pem
            fi
          done
        '';
        after = [ "dehydrated-dirs.service" ];
        requires = [ "dehydrated-dirs.service" ];
        before = [ "nginx.service" ];
        requiredBy = [ "nginx.service" ];
      };

      systemd.services.dehydrated-reload-nginx = {
        script = "systemctl reload nginx";
        after = [ "dehydrated.service" ];
        requiredBy = [ "dehydrated.service" ];
      };

      services.nginx.http = genAttrs domains (domain: ''
        # Respond to Let's Encrypt ACME challenge.
        location ^~ /.well-known/acme-challenge/ {
          alias /var/www/dehydrated/;
        }
      '');

      services.nginx.httpConfig = concatStrings (mapAttrsToList (domain: subdomains: ''
        # Redirect www.domain.tld to domain.tld.
        server {
          include ${config.path ../config/nginx/ssl.conf};
          ssl_certificate /var/lib/dehydrated/certs/${domain}/fullchain.pem;
          ssl_certificate_key /var/lib/dehydrated/certs/${domain}/privkey.pem;
          server_name www.${domain};
          return 301 $scheme://${domain}$request_uri;
        }
      '') cfg.domains);
    })
  ]);
}

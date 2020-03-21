{ config, pkgs, ... }:

with import ../../lib;

let
  user = config.services.nginx.user;

in {
  imports = [
    ../../modules/nginx.nix
  ];

  security.pam.loginLimits = [
    # Matches `worker_connections` of nginx.conf
    { domain = user; type = "soft"; item = "nproc";  value  = "4096"; }
    { domain = user; type = "hard"; item = "nproc";  value  = "4096"; }

    # Matches `worker_rlimit_nofile` of nginx.conf
    { domain = user; type = "soft"; item = "nofile"; value  = "65536"; }
    { domain = user; type = "hard"; item = "nofile"; value  = "65536"; }
  ];

  environment.etc."nginx/fastcgi_params".source = "${pkgs.nginx}/conf/fastcgi_params";

  users.systemUsers = "www-data";

  services.nginx = {
    enable = true;
    openPorts = true;
    user = mkDefault "www-data";
    group = mkDefault "www-data";
    config = ''
      include /run/nginx-nixcfg/shared/nginx.conf;
    '';
    httpConfig = ''
      include /run/nginx-nixcfg/shared/http.conf;
    '';
  };
}

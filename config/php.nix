{ config, pkgs, ... }:

let
  cfg = config.services.phpfpm;

in {
  imports = [
    ../modules/phpfpm.nix
  ];

  config = {
    environment.systemPackages = with pkgs; [ php ];

    services.phpfpm = {
      pools.www = {
        inherit (cfg) user group;
        settings = {
          "listen" = "/run/phpfpm/phpfpm.sock";
          "listen.owner" = config.services.nginx.user;
          "listen.group" = config.services.nginx.group;
          "listen.mode" = 0600;
          "listen.backlog" = -1;
          "pm" = "dynamic";
          "pm.max_children" = 8;
          "pm.start_servers" = 2;
          "pm.min_spare_servers" = 2;
          "pm.max_spare_servers" = 4;
          "pm.max_requests" = 500;
          "catch_workers_output" = true;
          "security.limit_extensions" = ".php";
          "env[TMP]" = "/tmp";
          "env[TMPDIR]" = "/tmp";
          "env[TEMP]" = "/tmp";
        };
      };

      phpOptions = ''
        error_reporting = E_ALL
        display_errors = On
        display_startup_errors = On
        html_errors = On

        default_charset = utf-8
        date.timezone = "${config.time.timeZone}"
        openssl.cafile = /etc/ssl/certs/ca-certificates.crt

        upload_max_filesize = 25M
        post_max_size = 25M

        ; https://www.scalingphpbook.com/best-zend-opcache-settings-tuning-config/
        zend_extension=opcache.so
        opcache.enable=1
        opcache.enable_cli=1
        opcache.revalidate_freq=0
        opcache.validate_timestamps=1 ; 0 in production
        opcache.max_accelerated_files=8192 ; max files that can be held in memory
        opcache.memory_consumption=192
        opcache.interned_strings_buffer=16
        opcache.fast_shutdown=1
      '';
    };
  };
}

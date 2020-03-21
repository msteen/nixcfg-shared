{ config, lib, ... }:

with lib;

{
  options = with types; {
    services.phpfpm = {
      user = mkOption {
        type = str;
        default = "www-data";
        description = ''
          User account under which PHP-FPM runs.
        '';
      };

      group = mkOption {
        type = str;
        default = "www-data";
        description = ''
          Group account under which PHP-FPM runs.
        '';
      };
    };
  };
}

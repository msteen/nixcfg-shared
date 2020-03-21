{ lib, config, ... }:

with lib;

let
  cfg = config.networking.router;

in {
  options = with types; {
    networking.router = {
      enable = mkEnableOption "router config";
    };
  };

  config = mkIf (!cfg.enable) {
    # https://www.kernel.org/doc/Documentation/networking/ip-sysctl.txt
    # http://unix.stackexchange.com/questions/90443/sysctl-proc-sys-net-ipv46-conf-whats-the-difference-between-all-defau
    boot.kernel.sysctl = {
      # Protect against TCP time-wait assassination hazards.
      "net.ipv4.tcp_rfc1337" = 1;

      # Enable source validation by strict reversed path (IP spoofing protection).
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;

      # Not a router.
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;

      # Log packets with impossible addresses.
      "net.ipv4.conf.all.log_martians" = 0;
      "net.ipv4.conf.default.log_martians" = 0;

      # Not a router.
      "net.ipv6.conf.default.autoconf" = 0;
      "net.ipv6.conf.default.accept_ra_defrtr" = 0;
      "net.ipv6.conf.default.accept_ra_pinfo" = 0;
      "net.ipv6.conf.default.accept_ra_rtr_pref" = 0;
      "net.ipv6.conf.default.router_solicitations" = 0;

      # How many global unicast IPv6 addresses can be assigned to each interface.
      "net.ipv6.conf.default.max_addresses" = 1;
    };
  };
}

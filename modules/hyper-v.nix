{ config, lib, ... }:

with lib;

let
  cfg = config.virtualisation.hypervGuest;

in {
  config = mkIf cfg.enable {
      # The value "nodev" is a special value that means GRUB will not be installed on any device.
    boot.loader.grub.device = "nodev";

    # No need to check journaling on boot when virtualizing.
    boot.initrd.checkJournalingFS = false;

    # Prevent memory allocation error: https://github.com/NixOS/nix/issues/421
    boot.kernel.sysctl."vm.overcommit_memory" = "1";

    # TODO: We can probably do without this.
    # services.xserver.videoDrivers = [ "fbdev" ];
  };
}

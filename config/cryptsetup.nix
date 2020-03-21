{ pkgs, ... }:

{
  boot.initrd = {
    availableKernelModules = [
      "aes"
      "aes_generic"
      "aes_x86_64"
      "blowfish"
      "cbc"
      "cryptd"
      "dm_crypt"
      "dm_mod"
      "ecb"
      "lrw"
      "serpent"
      "sha1"
      "sha256"
      "sha512"
      "twofish"
    ];

    extraUtilsCommands = ''
      copy_bin_and_libs ${pkgs.cryptsetup}/bin/cryptsetup
    '';
  };

  environment.systemPackages = with pkgs; [ cryptsetup ];

  environment.sudoAliases = [ "cryptsetup" ];
}

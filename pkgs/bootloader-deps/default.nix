{ config ? (import <nixpkgs/nixos> { }).config
, pkgs ? import <nixpkgs> { }
, initialRamdisk ? config.system.build.initialRamdisk
}:

with pkgs.lib;

pkgs.runCommand "bootloader-deps" { buildInputs = [ pkgs.nukeReferences ]; } ''
  mkdir $out

  cp ${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile} $out/kernel

  # We do not want linux as a dependency, because we already copied over the kernel,
  # and the rest is only needed for development.
  nuke-refs $out/kernel

  cp ${initialRamdisk}/${config.system.boot.loader.initrdFile} $out/initrd

  # There is no need to nuke the references of the initial ram disk,
  # because it is compressed, so Nix cannot determine its dependencies anyway.

  ${optionalString (config.boot.initrd.secrets != {}) ''
    cp ${config.system.build.initialRamdiskSecretAppender}/bin/append-initrd-secrets $out/append-initrd-secrets
  ''}

  cat <<EOF > $out/make-secrets-initrd
  if [[ -n \$TMPDIR ]]; then
    tmp_dir=\$TMPDIR
  else
    tmp_dir=/tmp
  fi
  cd "\$tmp_dir"
  tmp=$(mktemp secrets-initrd.XXXXXXXXXX)
  cp $out/initrd "\$tmp"
  ${config.system.build.initialRamdiskSecretAppender}/bin/append-initrd-secrets "\$tmp"
  echo "\$tmp_dir/\$tmp"
  EOF
  chmod +x $out/make-secrets-initrd

  # The system config has a lot of dependencies that drastically increase the size.
  systemConfig=${builtins.unsafeDiscardStringContext config.system.build.toplevel}
  echo "systemConfig=$systemConfig init=$systemConfig/init ${toString config.boot.kernelParams}" > $out/kernel-params
''

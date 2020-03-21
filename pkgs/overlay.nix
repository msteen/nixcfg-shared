let
  toNixpkgsStyle = self: super: self // {
    callPackage = super.lib.callPackageWith (super // builtins.removeAttrs super.xorg [ "callPackage" "newScope" "overrideScope" "packages" ]);
  };

in self: super:

# with toNixpkgsStyle self super;

let
  pkgs = self;

  shText = text: ''
    #!/bin/sh
    ${text}
  '';

  bashText = text: ''
    #!${super.bash}/bin/bash
    ${text}
  '';

  cfglib = import ../lib;

  channels = builtins.listToAttrs (map (channel: {
    name = builtins.replaceStrings ["-" "."] ["_" "_"] channel;
    value = import cfglib.channels.${channel} { config = { allowUnfree = true; }; overlays = []; };
  }) (builtins.attrNames cfglib.channels));

in channels // {
  inherit cfglib;

  overrideWithSelf = pkg: pkg.override (origArgs: builtins.intersectAttrs origArgs self);

  writeSh      = name: text: super.writeScript    name (  shText text);
  writeShBin   = name: text: super.writeScriptBin name (  shText text);
  writeBash    = name: text: super.writeScript    name (bashText text);
  writeBashBin = name: text: super.writeScriptBin name (bashText text);

  # The `--login` argument makes things like gpg-agent work properly.
  sshAsUser = user: self.writeSh "ssh-as-${user}" ''
    exec ${self.sudo}/bin/sudo --login --user="${user}" ${self.openssh}/bin/ssh "$@"
  '';

  ensureRoot = ''
    if [ $(id -u) -ne 0 ]; then
      if command -v sudo > /dev/null 2>&1; then
        exec sudo "$0" "$@"
      else
        echo 'You must be the root user to run this script' 1>&2
        exit 1
      fi
    fi
  '';

  syncUmountAll = ''
    sync
    swapoff -a
    cat /proc/mounts | grep '^/' | awk '{print $2}' | tac | xargs -I {} umount -r {}
  '';

  bashConfirm = prompt: disagree: error: ''
    IFS= read -n 1 -r -p "${prompt}? [Y/n] " answer
    if [[ -n $answer ]]; then
      echo
    fi
    if [[ $answer =~ (N|n) ]]; then
      ${disagree}
    elif ! [[ $answer =~ (Y|y| ) || -z $answer ]]; then
      echo 'Invalid answer, it should be either Y, y, <SPACE>, or <ENTER> for agreeing; and N or n for disagreeing' 1>&2
      ${error}
    fi
  '';

  rbash = super.runCommand "rbash" { } ''
    mkdir -p $out/bin
    ln -s ${super.bash}/bin/bash $out/bin/rbash
  '';
  rzsh = super.runCommand "rzsh" { } ''
    mkdir -p $out/bin
    ln -s ${super.zsh}/bin/zsh $out/bin/rzsh
  '';

  # grub4dos = super.callPackage ./grub4dos { stdenv = stdenv_32bit; };
  mklinuxpba = super.callPackage ./mklinuxpba { };
  qarma = super.libsForQt5.callPackage ./qarma { };
  samba-builtin = super.callPackage ./samba-builtin { };
  synergy2 = super.callPackage ./synergy2 { };
  sundials = super.callPackage ./sundials { };

  sedutil = super.callPackage ./sedutil { };
  sedutil-scripts = super.callPackage ./sedutil-scripts { };
  sedutil-scripts-unwrapped = super.callPackage ./sedutil-scripts/unwrapped.nix { };

  sysrq-scripts = super.callPackage ./sysrq-scripts { };
  port-up = super.callPackage ./port-up { };

  wrapScript = super.makeSetupHook { deps = [ super.makeWrapper ]; } ./setup-hooks/wrap-script.sh;

  nix-update-fetch = super.callPackage /home/matthijs/proj/nix-update-fetch { };
  nix-upfetch = super.callPackage /home/matthijs/proj/nix-upfetch { inherit (self) nix-prefetch; };
  nix-explorer = super.callPackage /home/matthijs/fork/nix-explorer { };

  test = super.callPackage ./test { };

  nix-gitignore = super.callPackage (self.fetchFromGitHub {
    owner = "siers";
    repo = "nix-gitignore";
    rev = "eba31084240f510ba7ec60a611a52826211ecbab";
    sha256 = "04f920mdppisvqf25b7vwpz1caq91sj6xa4a48nwwrygzxhjg3v7";
  }) { };

  # To allow other users access to a FUSE file system, you need to specify the `allow_other` option.
  # https://unix.stackexchange.com/questions/59685/sshfs-mount-sudo-gets-permission-denied/59695#59695

  # https://nixos.org/nix-dev/2016-September/021768.html
  sshfs = user: host: path: {
    fsType = "fuse";
    device = "${self.sshfsFuse}/bin/sshfs#${host}:${path}";
    options = [
      "ssh_command=${self.sshAsUser user}"
      "noauto" "x-systemd.automount" "auto_unmount" "_netdev" "reconnect" "allow_other" "follow_symlinks"
    ];
  };

  overlayHaskellPackages = haskellPackages: overlay: haskellPackages.override (oldAttrs: {
    overrides = super.lib.composeExtensions (oldAttrs.overrides or (_: _: {})) overlay;
  });
}

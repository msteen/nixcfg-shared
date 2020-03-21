{ config, pkgs, ... }:

with import ../lib;

let
  sshPort = head config.services.openssh.ports;
  cfg = config.nix;

  # ${pkgs.openssh}/bin/ssh -q -o BatchMode=yes -o ConnectTimeout=1 "$remote" exit
  writeOptSubstsWrapper = name: cmd: hiPrio (pkgs.writeBashBin "${name}-wrapped" ''
    subs=()
    for sub in ${toString cfg.optionalSubstituters}; do
      scheme=''${sub%%://*}
      echo scheme $scheme
      if ! [[ $scheme =~ ^ssh(-ng)?$ ]]; then
        echo "Scheme '$scheme' of optional substituter '$sub' is not supported in optional substituters" 1>&2
        exit 1
      fi
      remote=''${sub##*://}
      host=''${sub##*@}
      echo host $host
      echo remote $remote
      if ${pkgs.nmap}/bin/nmap --unprivileged -n --initial-rtt-timeout 50ms --max-retries 0 -PS${sshPort} -p ${sshPort} "$host" 2>/dev/null | ${pkgs.gnugrep}/bin/grep --quiet '1 host up'; then
        subs+=$sub
      else
        echo "warning: could not connect with optional substituter '$sub'" 1>&2
        subDown=1
      fi
    done
    if [[ -n $subDown ]]; then
      ${bashConfirm "Are you sure you want to continue even though some optional substituters are not up" "exit 0" "exit 1"}
    fi
    ${cmd name}
  '');

  preCmd = pkg: name: ''${pkg}/bin/${name} --option extra-substituters "''${subs[*]}" "$@"'';

in {
  options.nix.optionalSubstituters = with types; mkOption {
    type = loeOf str;
    default = [];
    description = ''
      Extra substituters that are ignored when inaccessible.
    '';
  };

  config = mkIf (cfg.optionalSubstituters != []) {
    environment.systemPackages = (map (name: writeOptSubstsWrapper name (preCmd config.nix.package.out)) [
      "nix"
      "nix-build"
      "nix-env"
      "nix-shell"
      "nix-store"
    ] ++ [
      (writeOptSubstsWrapper "nixos-rebuild" (preCmd config.system.build.nixos-rebuild))
      (writeOptSubstsWrapper "nixops" (name: ''
        ${pkgs.nixops}/bin/${name} "$@" --option extra-substituters "''${subs[*]}"
      ''))
      (pkgs.runCommand "opt-subs-unwrapped" {} ''
        mkdir -p $out/bin
        for bin in nix nix-build nix-env nix-shell nix-store; do
          ln -s ${config.nix.package.out}/bin/$bin $out/bin/$bin-unwrapped
        done
        ln -s ${config.system.build.nixos-rebuild}/bin/nixos-rebuild $out/bin/nixos-rebuild-unwrapped
        ln -s ${pkgs.nixops}/bin/nixops $out/bin/nixops-unwrapped
      '')
    ]);

    environment.aliases =
      (genAttrs [
        "nix"
        "nix-build"
        "nix-env"
        "nix-shell"
        "nix-store"
      ] (name: "${name}-wrapped"))
      //
      (genAttrs [
        "nixos-rebuild"
        "nixops"
      ] (name: "sudo ${name}-wrapped"));
  };
}

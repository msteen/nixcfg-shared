# It cannot be part of an overlay, because it is used to create modules that are imported,
# and since nixpkgs.overlays is part of config, and config depends on imports,
# this causes infinite recursion.
{ lib, pkgs }:

with lib;

let
  stateDir = "/var/lib/nixos-files";

  fileOptions = kind: with types; {
    enable = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether the target ${kind} should be generated.
      '';
    };

    target = mkOption {
      type = str;
      description = ''
        Name of the target ${kind}.
      '';
    };

    source = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        Path to the source ${kind}.
      '';
    };

    mode = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Mode of the created ${kind}.
      '';
    };

    uid = mkOption {
      type = nullOr int;
      default = null;
      description = ''
        UID of the created ${kind}.
      '';
    };

    gid = mkOption {
      type = nullOr int;
      default = null;
      description = ''
        GID of the created ${kind}.
      '';
    };

    user = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        User name of the created ${kind}. This option takes precedence over <literal>uid</literal>.
      '';
    };

    group = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Group name of the created ${kind}. This option takes precedence over <literal>gid</literal>.
      '';
    };
  };

  fileConfig = name: config: {
    target = mkDefault name;
    user = mkIf (config.uid != null) (mkDefault "+${toString config.uid}");
    group = mkIf (config.gid != null) (mkDefault "+${toString config.gid}");
  };

  fileModule = prefix: { name, config, ... }: {
    options = with types; {
      text = mkOption {
        default = null;
        type = nullOr lines;
        description = "Text of the created file.";
      };
    } // fileOptions "file";

    config = {
      source = mkIf (config.text != null)
        (mkDefault (pkgs.writeText "${prefix}-${replaceStrings ["."] ["-"] (baseNameOf name)}" config.text));
    } // fileConfig name config;
  };

  dirModule = prefix: { name, config, ... }: {
    options = fileOptions "directory";
    config = fileConfig name config;
  };

  attrsToEnv = attrs: concatStringsSep " " (mapAttrsToList (name: value: "${name}=${escapeShellArg value}") attrs);

  makeFilesModule =
  { path
  , root
  , fileMode ? "644"
  , dirMode ? "755"
  , user ? "root"
  , group ? "root"
  }: { config, ... }:
  let
    cfg = attrByPath path {} config;

    key = concatStringsSep "-" path;

    setupFiles = kind: files: concatStringsSep "\n" (map (setupFile kind) (filter (file: file.enable) (attrValues files)));
    setupFile = kind: file: ''${attrsToEnv {
      inherit kind;
      target = "${root}/${file.target}";
      symlink = with file; mode == null && user == null && group == null;
      inherit (file) source mode user group;
    }} setup_file'';

    changedFile = "${stateDir}/${key}/changed";
    linkedSetupFile = "${stateDir}/${key}/setup-link";

    makeChangedFile = dirs: files: "find ${concatStringsSep " " (map (target: ''"$(realpath -m ${escapeShellArg "${root}/${target}"})"'') (map (d: d.target) (attrValues dirs) ++ map (f: f.target) (attrValues files)))} -maxdepth 0 -printf '%Cs %p\\n' > ${changedFile}";

    # We need to track the state because we need to know if files should be deleted.
    # The timestamp check does not work because if a file in the config was changed,
    # the target file and the state remained unchanged, so they will will always succeed the check.
    setup-files = pkgs.writeBash "setup-files.sh" ''
      PATH=${makeBinPath (with pkgs; [ coreutils findutils ])}

      root=$(realpath -m '${root}')
      state_dir='${stateDir}/${key}'
      changed_file='${changedFile}'
      linked_setup_file='${linkedSetupFile}'
      declare -A old_state
      declare -A new_state

      old_link=$(basename "$(realpath -m "$linked_setup_file")")
      new_link=$(basename "$BASH_SOURCE")

      [[ $new_link != $old_link ]] && different_setup=1 || different_setup=0

      remove_file() {
        rm -v "$1"
      }

      make_parents() {
        local parent=$target parents=()
        while parent="$(dirname "$parent")" && [[ ! -d $parent ]]; do
          parents+=$parent
        done
        if (( ''${#parents[@]} == 0 )); then return 0; fi
        while IFS= read -r parent; do
          install -d --mode="${dirMode}" --owner="${user}" --group="${group}" -v "$parent"
        done <<< "$(printf '%s\n' "''${parents[@]}" | tac)"
      }

      make_file() {
        make_parents
        if [[ -n $symlink ]]; then
          ln -sfT -v "$source" "$target"
        else
          install --mode="''${mode:-${fileMode}}" --owner="''${user:-${user}}" --group="''${group:-${group}}" --no-target-directory -v "$source" "$target"
        fi
      }

      make_directory() {
        make_parents
        if [[ -n $symlink || -n $source ]]; then
          ln -sfT -v "$source" "$target"
        else
          install -d --mode="''${mode:-${dirMode}}" --owner="''${user:-${user}}" --group="''${group:-${group}}" -v "$target"
        fi
      }

      install_file() {
        if [[ $kind == directory ]]; then
          make_directory
        else
          make_file
        fi
      }

      setup_file() {
        local real_target
        real_target=$(realpath -m "$target")
        if [[ $real_target != $root* ]]; then
          echo "file '$target' is outside '$root'" 1>&2
          exit 1
        fi
        target=$real_target
        new_state[$target]=1
        if [[ ! -e $target ]] || (( different_setup || $(stat -c '%Z' "$target") != ''${old_state[$target]} )); then
          install_file
        fi
      }

      mkdir -p "$state_dir"

      if [[ -f $changed_file ]]; then
        while IFS=' ' read -r ctime file; do
          if [[ -z $ctime ]]; then continue; fi
          old_state[$file]=$ctime
        done <<< "$(< "$changed_file")"
      fi

      ${setupFiles "directory" cfg.dirs}
      ${setupFiles "file" cfg.files}

      for file in "''${!old_state[@]}"; do
        if [[ -z ''${new_state[$file]} ]]; then
          remove_file "$file"
        fi
      done

      ${makeChangedFile cfg.dirs cfg.files}

      ln -sfT "$new_link" "$linked_setup_file"
    '';

  in {
    options = setAttrByPath path (with types; {
      enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Whether files and directories should be generated in the root directory.
        '';
      };

      root = mkOption {
        type = path;
        description = ''
          The root directory for the files and directories.
          All files and directories will be relative to the root directory.
          And symlinks are not allowed to point outside the root directory.
        '';
      };

      files = mkOption {
        type = loaOf (submodule (fileModule key));
        default = {};
        description = ''
          A generalization of the <literal>environment.etc</literal> option for files in the specified root directory.
        '';
      };

      dirs = mkOption {
        type = loaOf (submodule (dirModule key));
        default = {};
        description = ''
          A generalization of the <literal>environment.etc</literal> option for directories in the specified root directory.
        '';
      };
    });

    config = mkIf (cfg.dirs != {} || cfg.files != {}) ({
      systemd.services."${key}-files" = {
        description = "Setting up files for ${root}";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = "yes";
          ExecStart = setup-files;
          SyslogIdentifier = "${key}-files";
        };
        wantedBy = [ "multi-user.target" ];
      };

      system.nixosFilesKeys = [ key ];
    } // setAttrByPath path {
      root = mkDefault (defaults.root);
    });
  };

in makeFilesModule

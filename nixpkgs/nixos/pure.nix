with import ../lib;

# https://git.sharcnet.ca/nix/nix/commit/d4dcffd64349bb52ad5f1b184bee5cc7c2be73b4
let
  pureBuiltins =
    # The builtins currentTime, currentSystem and storePath throw an error.
    builtins // genAttrs [ "currentTime" "currentSystem" "storePath" ] (name:
      throw "builtins.${name} is not allowed in pure evaluation mode"
    ) // {
      # $NIX_PATH and -I are ignored.
      nixPath = {};

      # The builtins fetchGit and fetchMercurial require a rev attribute.
      fetchGit = args@{ rev, ... }: builtins.fetchGit args;
      fetchMercurial = args@{ rev, ... }: builtins.fetchMercurial args;

      # The builtins fetchurl and fetchTarball require a sha256 attribute.
      fetchurl = args@{ sha256, ... }: builtins.fetchurl args;
      fetchTarball = args@{ sha256, ... }: builtins.fetchTarball args;
    };

  pureImport = scopedImport {
    builtins = pureBuiltins;
    import = path: pureImport (path);
  };

in pureImport ./.

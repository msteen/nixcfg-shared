let
  channelRevs = {
    "nixos-18.09"    = "a7e559a5504572008567383c3dc8e142fa7a8633";
    "nixos-19.03"    = "34c7eb7545d155cc5b6f499b23a7cb1c96ab4d59";
    "nixos-19.09"    = "ce9f1aaa39ee2a5b76a9c9580c859a74de65ead5";
    "nixos-20.03"    = "da92e0566d1381184faae4f2c2a69f5ba2a2a08d";
    "nixos-unstable" = "82b54d490663b6d87b7b34b9cfc0985df8b49c7d";
  };

  channelNames = builtins.attrNames channelRevs;

  channelFetchGitArgs = builtins.listToAttrs (map (name: {
    inherit name;
    value = {
      url = "https://github.com/NixOS/nixpkgs.git";
      ref = "refs/heads/${name}";
      rev = channelRevs.${name};
    };
  }) channelNames);

  channels = builtins.listToAttrs (map (name: {
    inherit name;
    value = builtins.fetchGit channelFetchGitArgs.${name};
  }) channelNames);

  lastStableChannel = builtins.foldl' (stableChannel: channel:
    if builtins.match "nixos-[0-9]{2}.[0-9]{2}" channel != null then channel else stableChannel
  ) null channelNames;

  lastStableLib = import "${channels.${lastStableChannel}}/lib";
  lastStableLibNix = with channelFetchGitArgs.${lastStableChannel}; ''
    import "''${builtins.fetchGit {
      url = "${url}";
      ref = "${ref}";
      rev = "${rev}";
    }}/lib"'';

  overlay = self: super: {
    lib = self;

    inherit channels lastStableChannel lastStableLib lastStableLibNix;

    securePath = path:
      let
        pathStr = toString path;
      in if self.hasPrefix "/nix/store/" pathStr
      then throw "secure path cannot be in Nix store '${pathStr}'"
      else pathStr;

    nixosProfileImports = profilePath: with self;
      let
        pkgsConfig = { config, ... }: {
          system.nixpkgsOverlayFiles =
            let p = config.path (profilePath + /pkgs/overlay.nix);
            in mkIf (pathExists p) p;
        };

        modulesImports =
          let p = profilePath + /modules;
          in optionals (pathExists p) (listDir p);

      in optionals (profilePath != null) ([ pkgsConfig ] ++ modulesImports);

    addProfileConfig = configuration: { imports = [ configuration ] ++ self.nixosProfileImports ../.; };
  };

  overlays = [ (import ./overlay.nix) overlay ];

in with lastStableLib; fix (foldl' (flip extends) (_: builtins // lastStableLib) overlays)

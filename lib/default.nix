let
  channelsMeta = {
    "nixos-18.09" = {
      rev = "a7e559a5504572008567383c3dc8e142fa7a8633";
      sha256 = "16j95q58kkc69lfgpjkj76gw5sx8rcxwi3civm0mlfaxxyw9gzp6";
    };
    "nixos-19.03" = {
      rev = "34c7eb7545d155cc5b6f499b23a7cb1c96ab4d59";
      sha256 = "11z6ajj108fy2q5g8y4higlcaqncrbjm3dnv17pvif6avagw4mcb";
    };
    "nixos-19.09" = {
      rev = "ce9f1aaa39ee2a5b76a9c9580c859a74de65ead5";
      sha256 = "1s2b9rvpyamiagvpl5cggdb2nmx4f7lpylipd397wz8f0wngygpi";
    };
    "nixos-20.03" = {
      rev = "da92e0566d1381184faae4f2c2a69f5ba2a2a08d";
      sha256 = "0kavxgmxkfgz4fhgz8b0a91b4x2nzpdwlps8hlx050d65s34hvd1";
    };
    "nixos-unstable" = {
      rev = "ddf87fb1baf8f5022281dad13fb318fa5c17a7c6";
      sha256 = "1xd6lz11lp7gqp00qfkk9h4nj4hvigm2xk1gi6css0r7sjw1chg4";
    };
  };

  channelNames = builtins.attrNames channelsMeta;

  channelFetchTarballArgs = builtins.listToAttrs (map (name: with channelsMeta.${name}; {
    inherit name;
    value = {
      url = "https://github.com/NixOS/nixpkgs/tarball/${rev}";
      inherit sha256;
    };
  }) channelNames);

  channels = builtins.listToAttrs (map (name: {
    inherit name;
    value = fetchTarball channelFetchTarballArgs.${name};
  }) channelNames);

  lastStableChannel = builtins.foldl' (stableChannel: channel:
    if builtins.match "nixos-[0-9]{2}.[0-9]{2}" channel != null then channel else stableChannel
  ) null channelNames;

  lastStableLib = import "${channels.${lastStableChannel}}/lib";
  lastStableLibNix = with channelFetchTarballArgs.${lastStableChannel}; ''
    import "''${fetchTarball {
      url = "${url}";
      sha256 = "${sha256}";
    }}/lib"'';

  overlay = self: super: {
    lib = self;

    inherit channels channelsMeta lastStableChannel lastStableLib lastStableLibNix;

    securePath = path:
      let
        pathStr = toString path;
      in if self.hasPrefix "/nix/store/" pathStr
      then throw "secure path cannot be in Nix store '${pathStr}'"
      else pathStr;

    nixosProfileImports = profilePath: with self;
      let
        pkgsConfig = { config, ... }: {
          nixpkgs.overlays =
            let p = config.path (profilePath + /pkgs/overlay.nix);
            in optional (pathExists p) (import p);
        };

        modulesImports =
          let p = profilePath + /modules;
          in optionals (pathExists p) (listDir p);

      in optionals (profilePath != null) ([ pkgsConfig ] ++ modulesImports);

    addProfileConfig = configuration: { imports = [ configuration ] ++ self.nixosProfileImports ../.; };
  };

  overlays = [ (import ./overlay.nix) overlay ];

in with lastStableLib; fix (foldl' (flip extends) (_: builtins // lastStableLib) overlays)

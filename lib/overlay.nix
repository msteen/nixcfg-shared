self: super: with self; {
  notNullOr = default: value: if value != null then value else default;

  quotRem = x: y: rec { quot = builtins.div x y; rem = x - y * quot; };

  repeat = n: x:
    let
      egyptianMul = out: n: dbl:
        if n > 1
        then let inherit (quotRem n 2) quot rem;
          in egyptianMul (if rem > 0 then out ++ dbl else out) quot (dbl ++ dbl)
        else out ++ dbl;
    in if n < 1 then [] else egyptianMul [] n [ x ];

  repeatString = n: s:
    let
      egyptianMul = out: n: dbl:
        if n > 1
        then let inherit (quotRem n 2) quot rem;
          in egyptianMul (if rem > 0 then out + dbl else out) quot (dbl + dbl)
        else out + dbl;
    in if n < 1 then "" else egyptianMul "" n s;

  unlines = lines: splitString "\n" (removeSuffix "\n" lines);
  lines = ss: concatMapStrings (s: s + "\n") ss;
  lines' = ss: concatStringsSep "\n" ss;
  commaLines = elems: concatStringsSep "," (self.unlines elems);
  fileLines = file: self.unlines (readFile file);
  nonl = s: removeSuffix "\n" s;

  setElem = list: index: value: take index list ++ [ value ] ++ drop (index + 1) list;

  mapToAttrs = f: foldl' (attrs: value: let name = f value; in if attrs ? ${name} then attrs else attrs // { ${name} = value; }) {};
  foldrAttrs = op: nul: attrs: foldr (name: res: op name attrs.${name} res) nul (attrNames attrs);

  listFiles = dir: foldrWithName (file: type: files:
    let path = dir + "/${file}"; in if type == "directory" then (listFiles path) ++ files else [ path ] ++ files
  ) (readDir dir);
  listDir = dir: map (file: dir + "/${file}") (attrNames (readDir dir));
  listPubs = dir: concatMap (contextDir: filter (hasSuffix ".pub") (self.listDir contextDir)) (self.listDir dir);

  stripHash = path: let m = split "^[a-z0-9]{32}-" (baseNameOf path); in if length m == 3 then elemAt m 2 else path;

  safeDerivationName = name: concatStringsSep "-" (filter (x: !(builtins.isList x || x == "")) (builtins.split "[^+-._?=[:alnum:]]" (removeSuffix "\n" name)));

  absToPath = str: let str' = unsafeDiscardStringContext str; in assert hasPrefix "/" str'; /. + substring 1 (-1) str';

  toPath = relToPath: str: let str' = builtins.unsafeDiscardStringContext str; in if hasPrefix "/" str'
    then /. + (substring 1 (-1) str')
    else let ty = builtins.typeOf relToPath; in if ty == "path" || ty == "string" && hasPrefix "/" relToPath
      then relToPath + "/${str'}"
      else throw "Relative string paths can only be made paths by absolute paths";

  mkIfExists = path: mkIf (pathExists path) path;

  mkForceDefault = mkOverride 999;

  types = super.types // rec {
    const = value: mkOptionType {
      name = "const";
      description = "const of ${toString value}";
      check = x: x == value;
      merge = mergeEqualOption;
    };

    # https://github.com/NixOS/nixpkgs/pull/30135
    loeOf = elemType:
    let
      convElemDef = def: if !(isList def.value) then {
        inherit (def) file;
        value = singleton def.value;
      } else def;

    in mkOptionType {
      name = "loeOf";
      description = "list or element of ${elemType.description}s";
      check = x: isList x || elemType.check x;
      merge = loc: defs: (types.listOf elemType).merge loc (map convElemDef defs);
      getSubOptions = prefix: elemType.getSubOptions (prefix ++ ["*"]);
      getSubModules = elemType.getSubModules;
      substSubModules = m: loeOf (elemType.substSubModules m);
      functor = (defaultFunctor name) // { wrapped = elemType; };
    };

    aoeOf = elemType:
    let
      convElemDef = def: if !(isAttrs def.value) then {
        inherit (def) file;
        value = listToAttrs (nameValuePair def.value.name def.value);
      } else def;

    in mkOptionType {
      name = "aoeOf";
      description = "attrs or named element of ${elemType.description}s";
      check = x: isAttrs x || elemType.check x;
      merge = loc: defs: (types.attrsOf elemType).merge loc (map convElemDef defs);
      getSubOptions = prefix: elemType.getSubOptions (prefix ++ ["<name>"]);
      getSubModules = elemType.getSubModules;
      substSubModules = m: aoeOf (elemType.substSubModules m);
      functor = (defaultFunctor name) // { wrapped = elemType; };
    };

    mapDef = f: type:
    let
      applyMapDef = def: {
        inherit (def) file;
        value = f def.file def.value;
      };

    in mkOptionType {
      name = "mapDef";
      description = "${type.description}";
      merge = loc: defs: type.merge loc (map applyMapDef defs);
      getSubOptions = type.getSubOptions;
      getSubModules = type.getSubModules;
      substSubModules = m: mapDef f (type.substSubModules m);
      functor = (defaultFunctor name) // { wrapped = type; };
    };
  };
}


# Organization

Each nixcfg (Nix config) profile follows the same organizational structure. This allows configuration by convention, e.g. if a profile contains the file pkgs/overlay.nix, it is automatically included in the list of nixpkgs overlays.

## Files and directories

The following files and directories hold special meaning within a nixcfg profile.

### /default.nix

Defines a list of nixcfg profiles it requires and defines how it can be resolved where a profile can be found.

Observation: It is not good enough to determine what profiles are required by keeping track of the profiles listed in the imports attribute, because /config/default.nix is optional and the profile could still be required for e.g. its packages. That is why an explicit list of profiles is being used.

### /lib

Observation: Given NixOS as it is right now, it is not possible to define lib through configuration (i.e. _module.args) and its not possible to pass the module arguments in some other manner. This is because for covenience sake, lib is almost always brought into scope at the top of any module. This causes the configuration to depend on lib, so lib cannot in turn depend in any way on the configuration, otherwise it would result in infinite recursion. So without tweaking any of the source code of nixpkgs (e.g. nixpkgs/lib/modules.nix and nixpkgs/nixos), we cannot introduce our extended lib this way. The only other way to introduce something within a Nix file, is to use imports, so instead of having an additional module argument, lib would have to be imported as a file. Fortunately the value results of imports are cached in Nix, so importing the same lib file multiple times does not result in multiple evaluations.

### /lib/default.nix

The custom lib used by nixcfg.

### /config and /modules
Contains files containing snippets of NixOS configuration, e.g. config/sedutil.nix contains the NixOS configuration necessary to encrypt a drive with sedutil. The difference between NixOS configuration (found in /config) and NixOS modules (found in /modules) is that NixOS configuration only set options defined in the modules (like most peoples /etc/nixos/configuration.nix file would do), while NixOS modules define a set of options and its config section will always be guarded and based on the options defined within the module. NixOS does not make this distinction, so technically both the files found in /config and /modules are valid NixOS modules.

If either in `/config` or `/modules` additional files are needed, instead of making e.g. `/config/name.nix` it will become `/config/name/default.nix` and then additional files needed for `name` will also be placed under `/config/name`.

### /config/default.nix

Observation: Configuration based on nixcfg profile conventions needs:
1. its logic to be introduced local to /config/default.nix, otherwise it cannot be used standalone, like: `import <nixpkgs/nixos> { configuration = [ (resolvePath /profile/config) other.nix ] }`
2. access to /default.nix to know which profiles are required
3. the logic needs to be implemented as a module, it cannot be part of e.g. `/shared/config`, because there is no guarantee it will be imported.

To get either a function that adds the right import to the imports attribute of the configuration `f ./. { ... }` (clearest, since its only needed once at top-level + no extra importer function needed, so this will be used) or calling the function when adding its result to the imports `{ imports = [ (f ./.) ... ]; ... }`, we could either import some external nix file that defines this function, or we could leverage the extended lib that is already an external import (best UI, so this will be used).

### /pkgs

### /pkgs/overlay.nix

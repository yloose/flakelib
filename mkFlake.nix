{ inputs, ... }@cfg: let
  nixpkgs = inputs.nixpkgs;
  self = inputs.self;
  defaultImport = default: path: if builtins.pathExists path && (nixpkgs.lib.pathIsDirectory path -> builtins.pathExists (path + "/default.nix")) then
    import path
  else default;
  customLib = defaultImport (_: {}) (self + "/lib") {inherit (nixpkgs) lib;};
  lib = nixpkgs.lib.extend (final: prev: prev // customLib);
in
  with lib;
  with builtins;
  with (import ./lib.nix);
  let
    systemHasUser = hostname: foldr (str: acc: acc || (hasSuffix hostname str)) false (attrNames (readDir (self + "/homes")));
    forEachUser = hostname: let
      users = lists.foldr (l: acc: acc ++ [(head l)]) [] (filter (l: hostname == elemAt l 1) (map (strings.splitString "@") (attrNames (readDir (self + "/homes")))));
    in
      attrsets.genAttrs users;

    overlays = if pathExists (self + "/overlays") then
        map (n: import (self + "/overlays/" + n) {inherit inputs;}) (attrNames (readDir (self + "/overlays")))
      else [];
  in {
      packages = if pathExists (self + "/packages/default.nix") then
          forAllSystems (system: import (self + "/packages") {pkgs = nixpkgs.legacyPackages.${system};})
        else { }; 

      devShells = if pathExists (self + "/shells") then forAllSystems (system: builtins.listToAttrs (lib.pipe
        (builtins.readDir (self + "/shells")) [
          (lib.filterAttrs (_: fileType: fileType == "directory"))
          (builtins.attrNames)
          (builtins.map (name: {
            inherit name;
            value = lib.callPackageWith (nixpkgs.legacyPackages.${system} // { inherit inputs; }) (self + "/shells/${name}") { };
          }))
        ]
      )) else { };

      apps = if pathExists (self + "/apps") then forAllSystems (system: builtins.listToAttrs (lib.pipe
        (builtins.readDir (self + "/apps")) [
          (lib.filterAttrs (_: fileType: fileType == "directory"))
          (builtins.attrNames)
          (builtins.map (name: {
            inherit name;
            value = import (self + "/apps/${name}") ({ pkgs = nixpkgs.legacyPackages.${system}; inherit system lib inputs; } // inputs );
          }))
        ]
      )) else { } // (if builtins.hasAttr "apps" cfg then 
        forAllSystems (system: lib.mapAttrs (_: v: v { pkgs = nixpkgs.legacyPackages.${system}; inherit system lib; }) (lib.filterAttrs (name: _: ! builtins.elem name (lib.attrNames lib.systems.examples)) cfg.apps))
          // (lib.filterAttrs (name: _: builtins.elem name (lib.attrNames lib.systems.examples)) cfg.apps)
      else { });

      nixosConfigurations = forEachSystem self (
        host:
          nixosSystem {
            modules = let
              overlayModule = {
                nixpkgs.overlays = mkBefore ([
                    (final: prev: (import (self + "/packages") {pkgs = prev;}))
                  ]
                  ++ overlays);
              };
              hmModules =
                if systemHasUser host.hostname
                then [
                  inputs.home-manager.nixosModules.home-manager
                  {
                    home-manager = {
                      useGlobalPkgs = false;
                      useUserPackages = true;
                      extraSpecialArgs = {inherit inputs; };
                      users = forEachUser host.hostname (username: {
                        imports =
                          [
                            overlayModule
                            {
                              options.flake.user.name = mkOption {
                                description = "The current username as provided by the flake.";
                                default = username;
                                type = types.str;
                              };
                            }
                            (self + "/homes/${username}@${host.hostname}/default.nix")
                          ]
                          ++ (importModules self "/modules/home")
                          ++ (getOptList cfg "homes.users.${username}@${host.hostname}.modules");
                      });
                    };
                  }
                ]
                else [];
            in
              [
                overlayModule
                (self + "/systems/${hostname}")
              ]
              ++ (importModules self "/modules/nixos")
              ++ hmModules
              ++ (getOptList cfg "systems.${host.hostname}.modules");
            specialArgs = { inherit hostname inputs; isVm = getEnv "VM" == "1"; };
          }
      );
  }

inputs: let
  nixpkgs = inputs.nixpkgs;
  self = inputs.self;
  defaultImport = default: path: if builtins.pathExists path && (nixpkgs.lib.pathIsDirectory path -> builtins.pathExists (path + "/default.nix")) then
    import path
  else default;
  customLib = defaultImport (_: {}) (self + "/lib") {inherit (nixpkgs) lib;};
  lib = nixpkgs.lib.extend (final: prev: prev // customLib);
in
  with lib;
  with builtins; let
    allSystems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = genAttrs allSystems;
    systemHasUser = hostname: foldr (str: acc: acc || (hasSuffix hostname str)) false (attrNames (readDir (self + "/homes")));
    forEachUser = hostname: let
      users = lists.foldr (l: acc: acc ++ [(head l)]) [] (filter (l: hostname == elemAt l 1) (map (strings.splitString "@") (attrNames (readDir (self + "/homes")))));
    in
      attrsets.genAttrs users;

    forEachSystem = let
      systems = attrNames (readDir (self + "/systems"));
    in
      attrsets.genAttrs systems;

    importModules = baseDir: if pathExists (self + baseDir) then
      lists.concatMap
      (p:
        if all (f: f (self + p + "/default.nix")) [pathExists] # Check if default.nix is a file and not a directory
        then [(self + p)]
        else importModules p)
      (mapAttrsToList (n: v: "${baseDir}/${n}")
        (filterAttrs (_: v: v == "directory")
          (readDir (self + baseDir))))
      else [];

    getOptList = attrset: pathStr: let
      accessPath = getAttr;
      path = strings.split "." pathStr;
    in
      if path == []
      then attrset
      else if hasAttr (head path) attrset
      then getOptList (tail path) (accessPath (head path) attrset)
      else [];

    overlays = if pathExists (self + "/overlays") then
        map (n: import (self + "/overlays/" + n) {inherit inputs;}) (attrNames (readDir (self + "/overlays")))
      else [];
  in {
      packages = if pathExists (self + "/packages/default.nix") then
          forAllSystems (system: import (self + "/packages") {pkgs = nixpkgs.legacyPackages.${system};})
        else { }; 

      nixosConfigurations = forEachSystem (
        hostname:
          nixosSystem {
            modules = let
              overlayModule = {
                nixpkgs.overlays = mkBefore ([
                    (final: prev: (import (self + "/packages") {pkgs = prev;}))
                  ]
                  ++ overlays);
              };
              hmModules =
                if systemHasUser hostname
                then [
                  inputs.home-manager.nixosModules.home-manager
                  {
                    home-manager = {
                      useGlobalPkgs = false;
                      useUserPackages = true;
                      extraSpecialArgs = {inherit inputs; isVm = getEnv "VM" == 1;};
                      users = forEachUser hostname (username: {
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
                            (self + "/homes/${username}@${hostname}/default.nix")
                          ]
                          ++ (importModules "/modules/home")
                          ++ (getOptList cfg "homes.users.${username}@${hostname}.modules");
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
              ++ (importModules "/modules/nixos")
              ++ hmModules
              ++ (getOptList cfg "systems.${hostname}.modules");
            specialArgs = { inherit hostname inputs; isVm = getEnv "VM" == "1"; };
          }
      );
  }

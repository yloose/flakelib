{
  config,
  lib,
  inputs,
  ...
} @ flake: {
  options = {
    hosts = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.submoduleWith {
        modules = [
          ({config, ...}: {
            options.users = lib.mkOption {
              type = lib.types.lazyAttrsOf (lib.types.submoduleWith {
                modules = [
                  ({
                    name,
                    config,
                    ...
                  }: {
                    options = {
                      enable = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                      };
                      username = lib.mkOption {
                        type = lib.types.str;
                        default = name;
                      };
                      modules = lib.mkOption {
                        type = lib.types.listOf lib.types.deferredModule;
                        default = [];
                      };
                    };

                    config.modules =
                      [{_module.args.username = config.username;}]
                      ++ flake.config.homeModules;
                  })
                  flake.config.homeDefaults
                ];
              });
              default = {};
            };
            config.modules = lib.mkIf (config.users != {}) [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = {
                    inherit inputs;
                    inherit (config) hostname;
                  };
                  users =
                    lib.mapAttrs' (_: u: lib.nameValuePair u.username {imports = u.modules;})
                    (lib.filterAttrs (_: u: u.enable) config.users);
                };
              }
            ];
          })
        ];
      });
    };
    homeDefaults = lib.mkOption {
      type = lib.types.deferredModule;
      default = {};
    };

    homeModules = lib.mkOption {
      type = lib.types.listOf lib.types.deferredModule;
      default = [];
    };

    flakelib.homes.path = lib.mkOption {
      type = lib.types.oneOf [lib.types.pathInStore lib.types.str];
      default = "/homes";
    };
    flakelib.homeModules.path = lib.mkOption {
      type = lib.types.oneOf [lib.types.pathInStore lib.types.str];
      default = "/modules/home";
    };
  };

  config.hosts = let
    entries = lib.mapAttrsToList (n: file: let
      parts = lib.splitString "@" n;
    in {
      user = lib.head parts;
      host = lib.elemAt parts 1;
      inherit file;
    }) (lib.importTree config.flakelib.homes.path);
  in
    lib.mapAttrs (_: es: {
      users = lib.listToAttrs (lib.map (e: lib.nameValuePair e.user {modules = [e.file];}) es);
    }) (lib.groupBy (e: e.host) entries);

  config.homeModules = lib.importModules config.flakelib.homeModules.path;
  config.outputs.homeModules.default = {imports = config.homeModules;};
}

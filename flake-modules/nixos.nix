{
  lib,
  config,
  inputs,
  ...
} @ flake: {
  options = {
    hosts = lib.mkOption {
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
              hostname = lib.mkOption {
                type = lib.types.str;
                default = name;
              };
              modules = lib.mkOption {
                type = lib.types.listOf lib.types.deferredModule;
                default = [];
              };
              specialArgs = lib.mkOption {
                type = lib.types.lazyAttrsOf lib.types.raw;
                default = {};
              };
            };

            config.specialArgs = {
              inherit inputs;
              inherit (config) hostname;
            };
            config.modules =
              flake.config.nixosModules
              ++ [
                {
                  networking.hostName = lib.mkDefault config.hostname;
                  nixpkgs = {overlays = flake.config.overlays;} // {inherit (flake.config.nixpkgs) config;};
                }
              ];
          })
          config.hostDefaults
        ];
      });
      default = {};
    };
    hostDefaults = lib.mkOption {
      type = lib.types.deferredModule;
      default = {};
    };

    nixosModules = lib.mkOption {
      type = lib.types.listOf lib.types.deferredModule;
      default = [];
    };

    flakelib = {
      hosts.path = lib.mkOption {
        type = lib.types.nullOr (lib.types.oneOf [lib.types.pathInStore lib.types.str]);
        default = "/hosts";
      };
      nixosModules.path = lib.mkOption {
        type = lib.types.nullOr (lib.types.oneOf [lib.types.pathInStore lib.types.str]);
        default = "/modules/nixos";
      };
    };
  };

  config.hosts = let
    hostFiles = lib.importTree config.flakelib.hosts.path;
  in
    lib.mapAttrs' (hostpath: file: {
      name = builtins.replaceStrings ["/"] ["-"] hostpath;
      value = {modules = [file];};
    })
    hostFiles;

  config.outputs.nixosConfigurations =
    lib.mapAttrs (
      _: host:
        lib.nixosSystem {
          inherit (host) specialArgs modules;
        }
    )
    (lib.filterAttrs (_: h: h.enable) config.hosts);

  config.nixosModules = lib.importModules config.flakelib.nixosModules.path;
  config.outputs.nixosModules.default = {imports = config.nixosModules;};
}

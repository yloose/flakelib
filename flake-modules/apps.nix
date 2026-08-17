{
  config,
  lib,
  inputs,
  ...
}: {
  options = {
    apps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [lib.types.pathInStore (lib.types.functionTo lib.types.attrs)]);
      default = {};
    };
    flakelib.apps.path = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [lib.types.pathInStore lib.types.str]);
      default = "/apps";
    };
  };

  config.apps = lib.importTree config.flakelib.apps.path;

  config.outputs.apps = let
    mkAppsForSystem = system:
      lib.mapAttrs (name: app:
        (if builtins.isFunction app then app else import app) {
          pkgs = config.pkgs.${system};
          inherit system lib inputs;
        })
      config.apps;
  in
    lib.genAttrs config.systems mkAppsForSystem;
}

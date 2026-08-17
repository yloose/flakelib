{
  config,
  lib,
  inputs,
  ...
}: {
  options = {
    packages = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = {};
    };
    flakelib.packages.path = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [lib.types.pathInStore lib.types.str]);
      default = "/packages";
    };
  };

  config.packages = lib.importTree config.flakelib.packages.path;

  config.overlays = lib.mkBefore [
    (final: prev:
      lib.callTree
      (extra: final.newScope ({inherit inputs;} // extra))
      (lib.nestAttrs config.packages))
  ];

  config.outputs.packages = lib.genAttrs config.systems (
    system:
      lib.filterAttrs (path: package: !(lib.hasInfix "/" path) || lib.isDerivation package)
      (lib.mapAttrs
        (path: _: lib.getAttrFromPath (lib.splitString "/" path) config.pkgs.${system})
        config.packages)
  );
}

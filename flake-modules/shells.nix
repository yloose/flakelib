{
  lib,
  inputs,
  config,
  ...
}: {
  options = {
    devShells = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = {};
    };
    flakelib.devShells.path = lib.mkOption {
      type = lib.types.oneOf [lib.types.pathInStore lib.types.str];
      default = "/shells";
    };
  };

  config.devShells = lib.importTree config.flakelib.devShells.path;

  config.outputs.devShells = let
    mkShellsForSystem = system:
      lib.mapAttrs (name: shell:
        config.pkgs.${system}.newScope { inherit inputs; } shell {})
      config.devShells;
  in
    lib.genAttrs config.systems mkShellsForSystem;
}

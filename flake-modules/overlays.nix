{
  config,
  lib,
  inputs,
  ...
}: {
  options = {
    overlays = lib.mkOption {type = lib.types.listOf lib.types.raw;};
    flakelib.overlays.path = lib.mkOption {
      type = lib.types.nullOr (lib.types.oneOf [lib.types.pathInStore lib.types.str]);
      default = "/overlays";
    };
  };

  config = let
    named = lib.mapAttrs (name: overlay: import overlay {inherit inputs;}) (lib.importTree config.flakelib.overlays.path);
  in {
    overlays = lib.attrValues named;
    outputs.overlays = named;
  };
}

{
  config,
  lib,
  inputs,
  ...
}: {
  options = {
    pkgs = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
    nixpkgs = {
      input = lib.mkOption {
        type = lib.types.raw;
        default = inputs.nixpkgs;
      };
      config = lib.mkOption {
        type = lib.types.attrs;
        default = {};
      };
    };
  };

  config.pkgs = lib.genAttrs config.systems (system:
    lib.mkDefault (import config.nixpkgs.input {
      inherit system;
      inherit (config.nixpkgs) config;
      inherit (config) overlays;
    }));
}

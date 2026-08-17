{lib, ...}: {
  options = {
    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
    outputs = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
  };

  config.outputs.lib = lib;
}

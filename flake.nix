{
  description = "Flake library functions";

  outputs = inputs: {
    mkFlake = import ./mkFlake.nix;
  };
}

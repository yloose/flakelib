{
  inputs,
  src,
}: let
  flakelib = import ./lib.nix;
  base = inputs.nixpkgs.lib;
  flakelibOverlay = flakelib.overlay src;
  repoOverlay =
    if builtins.pathExists (src + "/lib")
    then import (src + "/lib") {inherit inputs;}
    else _: _: {};
in
  base.extend (base.composeManyExtensions [flakelibOverlay repoOverlay])

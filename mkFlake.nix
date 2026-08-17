{
  inputs,
  src ? throw "flakelib: mkFlake requires 'src', the root of the calling flake.",
  ...
} @ cfg: let
  mkLib = import ./mkLib.nix;
  lib = mkLib {inherit inputs src;};
in
  (lib.evalModules {
    class = "flake";
    specialArgs = {inherit inputs src;};
    modules = [
      ./flake-modules/core.nix
      ./flake-modules/packages.nix
      ./flake-modules/shells.nix
      ./flake-modules/apps.nix
      ./flake-modules/overlays.nix
      ./flake-modules/nixos.nix
      ./flake-modules/home-manager.nix
      ./flake-modules/nixpkgs.nix
      (builtins.removeAttrs cfg ["inputs" "src"])
    ];
  })
  .config
  .outputs

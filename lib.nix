let
  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (builtins.attrNames attrs);
  filterAttrs = pred: set: removeAttrs set (builtins.filter (name: !pred name set.${name}) (builtins.attrNames set));
  nameValuePair = name: value: { inherit name value; };
  genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
in rec {
  forAllSystems = genAttrs systems;
  importModules = self: baseDir: if builtins.pathExists (self + baseDir) then
    builtins.concatMap
    (p:
      if builtins.all (f: f (self + p + "/default.nix")) [builtins.pathExists]
      then [(self + p)]
      else importModules p)
    (mapAttrsToList (n: v: "${baseDir}/${n}")
      (filterAttrs (_: v: v == "directory")
        (builtins.readDir (self + baseDir))))
    else [];
}

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
  importModulesWithDefaultFile = defaultFilename: self: baseDir: if builtins.pathExists (self + baseDir) then
    builtins.concatMap
    (p:
      if builtins.all (f: f (self + p + "/${defaultFilename}")) [builtins.pathExists]
      then [(self + p + "/${defaultFilename}")]
      else importModules p)
    (mapAttrsToList (n: v: "${baseDir}/${n}")
      (filterAttrs (_: v: v == "directory")
        (builtins.readDir (self + baseDir))))
    else [];
  importModules = importModulesWithDefaultFile "default.nix";

  getOptList = attrset: pathStr: let
    accessPath = builtins.getAttr;
    path = builtins.filter builtins.isString (builtins.split "\\." pathStr);
  in
    if path == []
    then attrset
    else if builtins.hasAttr (builtins.head path) attrset
    then getOptList (builtins.tail path) (accessPath (builtins.head path) attrset)
    else [];


  forEachSystem = self: let
    systems = builtins.attrNames (builtins.readDir (self + "/systems"));
  in
    genAttrs systems;
}

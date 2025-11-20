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
      else importModulesWithDefaultFile defaultFilename self p)
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
    find = path: let
      contents = builtins.readDir path;
    in
      if builtins.hasAttr "default.nix" contents && contents."default.nix" == "regular" then [ "" ]
      else
        builtins.concatMap (name: if contents."${name}" == "directory" then
            builtins.map (p: if p == "" then name else "${name}/${p}") (find (path + "/${name}"))
          else
            []
        ) (builtins.attrNames contents);
    systems = builtins.map (hostpath: rec {
      hostPath = "${self}/systems/${hostpath}";
      entryModule = "${hostPath}/default.nix";
      hostname = builtins.replaceStrings ["/"] ["-"] hostpath;
    })
      (find (self + "/systems"));
  in
    f: builtins.listToAttrs (builtins.map (host: {name = host.hostname; value = f host;}) systems);

  eachSystem = eachSystemOp (
    f: attrs: system:
    let
      ret = f system;
    in
    builtins.foldl' (
      attrs: key:
      attrs
      // {
        ${key} = (attrs.${key} or { }) // {
          ${system} = ret.${key};
        };
      }
    ) attrs (builtins.attrNames ret)
  );
  allSystems = eachSystem systems;

  eachSystemOp = op: systems: f: builtins.foldl' (op f) { } systems;
}

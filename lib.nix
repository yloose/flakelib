let
  filterAttrs = pred: set: removeAttrs set (builtins.filter (name: !pred name set.${name}) (builtins.attrNames set));
  nameValuePair = name: value: {inherit name value;};
  genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
in rec {
  forAllSystems = genAttrs systems;
  importTreeWithDefaultFile = defaultFileName: self: startDir: let
    root =
      if builtins.isPath startDir
      then startDir
      else if startDir == "" || startDir == "."
      then self
      else self + "/${startDir}";

    walk = rel: dir: let
      entries = builtins.readDir dir;
    in
      if rel != "" && (entries.${defaultFileName} or "directory") != "directory"
      then {${rel} = dir + "/${defaultFileName}";}
      else
        builtins.foldl'
        (acc: n:
          acc
          // walk (
            if rel == ""
            then n
            else "${rel}/${n}"
          ) (dir + "/${n}"))
        {}
        (builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries));
  in
    walk "" root;
  importTree = importTreeWithDefaultFile "default.nix";

  importModulesWithDefaultFile = defaultFilename: self: baseDir: let
    dir = "${self}/${baseDir}";
    defaultFile = "${dir}/${defaultFilename}";
  in
    if !(builtins.pathExists dir)
    then []
    else if builtins.pathExists defaultFile
    then [defaultFile]
    else
      builtins.concatMap
      (name: importModulesWithDefaultFile defaultFilename self "${baseDir}/${name}")
      (builtins.attrNames
        (filterAttrs (_: v: v == "directory")
          (builtins.readDir dir)));
  importModules = importModulesWithDefaultFile "default.nix";

  getOptList = attrset: pathStr: let
    path = builtins.filter builtins.isString (builtins.split "\\." pathStr);
  in
    if path == [] || path == [""]
    then attrset
    else if builtins.hasAttr (builtins.head path) attrset
    then getOptList (builtins.getAttr (builtins.head path) attrset) (builtins.concatStringsSep "." (builtins.tail path))
    else [];

  forEachSystem = self: let
    find = path: let
      contents =
        if builtins.pathExists path
        then builtins.readDir path
        else {};
    in
      if builtins.hasAttr "default.nix" contents && contents."default.nix" == "regular"
      then [""]
      else
        builtins.concatMap (
          name:
            if contents."${name}" == "directory"
            then
              map (p:
                if p == ""
                then name
                else "${name}/${p}") (find (path + "/${name}"))
            else []
        ) (builtins.attrNames contents);
    systems =
      map (hostpath: rec {
        hostPath = "${self}/systems/${hostpath}";
        entryModule = "${hostPath}/default.nix";
        hostname = builtins.replaceStrings ["/"] ["-"] hostpath;
      })
      (find "${self}/systems");
  in
    f:
      builtins.listToAttrs (map (host: {
          name = host.hostname;
          value = f host;
        })
        systems);

  eachSystem = eachSystemOp (
    f: attrs: system: let
      ret = f system;
    in
      builtins.foldl' (
        attrs: key:
          attrs
          // {
            ${key} =
              (attrs.${key} or {})
              // {
                ${system} = ret.${key};
              };
          }
      )
      attrs (builtins.attrNames ret)
  );
  allSystems = eachSystem systems;

  eachSystemOp = op: systems: f: builtins.foldl' (op f) {} systems;
}

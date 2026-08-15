let
  filterAttrs = pred: set: removeAttrs set (builtins.filter (name: !pred name set.${name}) (builtins.attrNames set));
  nameValuePair = name: value: {inherit name value;};
  genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
  hasPrefix = prefix: str: builtins.substring 0 (builtins.stringLength prefix) str == prefix;
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
in rec {
  forAllSystems = genAttrs systems;

  resolvePath = self: dir:
    if builtins.isPath dir
    then dir
    else let
      root = toString self;
      str = toString dir;
      unrooted =
        if str == root
        then ""
        else if hasPrefix "${root}/" str
        then builtins.substring (builtins.stringLength root + 1) (builtins.stringLength str) str
        else str;
      rel = builtins.head (builtins.match "/*(.*)" unrooted);
    in
      self
      + (
        if rel == "" || rel == "."
        then ""
        else "/${rel}"
      );

  importTreeWithDefaultFile = defaultFileName: self: startDir: let
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
    walk "" (resolvePath self startDir);
  importTree = importTreeWithDefaultFile "default.nix";

  importModulesWithDefaultFile = defaultFileName: self: baseDir: let
    walk = dir: let
      defaultFile = dir + "/${defaultFileName}";
    in
      if !(builtins.pathExists dir)
      then []
      else if builtins.pathExists defaultFile
      then [defaultFile]
      else
        builtins.concatMap
        (name: walk (dir + "/${name}"))
        (builtins.attrNames
          (filterAttrs (_: v: v == "directory")
            (builtins.readDir dir)));
  in
    walk (resolvePath self baseDir);
  importModules = importModulesWithDefaultFile "default.nix";

  withSelf = self: {
    importTree = importTree self;
    importTreeWithDefaultFile = defaultFileName: importTreeWithDefaultFile defaultFileName self;
    importModules = importModules self;
    importModulesWithDefaultFile = defaultFileName: importModulesWithDefaultFile defaultFileName self;
  };

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

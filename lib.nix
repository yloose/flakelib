let
  filterAttrs = pred: set: removeAttrs set (builtins.filter (name: !pred name set.${name}) (builtins.attrNames set));
  hasPrefix = prefix: str: builtins.substring 0 (builtins.stringLength prefix) str == prefix;
  splitOn = separator: str: let
    separatorLength = builtins.stringLength separator;
    strLength = builtins.stringLength str;
    walk = start: i:
      if i + separatorLength > strLength
      then [(builtins.substring start (strLength - start) str)]
      else if builtins.substring i separatorLength str == separator
      then [(builtins.substring start (i - start) str)] ++ walk (i + separatorLength) (i + separatorLength)
      else walk start (i + 1);
  in
    if separatorLength == 0
    then [str]
    else walk 0 0;
in rec {
  resolvePath = src: dir:
    if builtins.isPath dir
    then dir
    else let
      root = toString src;
      str = toString dir;
      unrooted =
        if str == root
        then ""
        else if hasPrefix "${root}/" str
        then builtins.substring (builtins.stringLength root + 1) (builtins.stringLength str) str
        else str;
      rel = builtins.head (builtins.match "/*(.*)" unrooted);
    in
      src
      + (
        if rel == "" || rel == "."
        then ""
        else "/${rel}"
      );

  resolveOptionalPath = src: dir:
    if dir == null
    then null
    else let
      root = resolvePath src dir;
    in
      if builtins.pathExists root
      then root
      else null;

  importTreeWithDefaultFile = defaultFileName: src: startDir: let
    walk = rel: dir: let
      entries = builtins.readDir dir;
    in
      if (entries.${defaultFileName} or "directory") != "directory"
      then {
        ${
          if rel == ""
          then "default"
          else rel
        } =
          dir + "/${defaultFileName}";
      }
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
    root = resolveOptionalPath src startDir;
  in
    if root == null
    then {}
    else walk "" root;
  importTree = importTreeWithDefaultFile "default.nix";

  importModulesWithDefaultFile = defaultFileName: src: baseDir: let
    walk = dir: let
      defaultFile = dir + "/${defaultFileName}";
    in
      if builtins.pathExists defaultFile
      then [defaultFile]
      else
        builtins.concatMap
        (name: walk (dir + "/${name}"))
        (builtins.attrNames
          (filterAttrs (_: v: v == "directory")
            (builtins.readDir dir)));
    root = resolveOptionalPath src baseDir;
  in
    if root == null
    then []
    else walk root;
  importModules = importModulesWithDefaultFile "default.nix";

  nestAttrsWithSeparator = separator: flat: let
    insert = attrs: path: value:
      if builtins.length path == 1
      then attrs // {${builtins.head path} = value;}
      else let
        name = builtins.head path;
      in
        attrs // {${name} = insert (attrs.${name} or {}) (builtins.tail path) value;};
  in
    builtins.foldl'
    (acc: key: insert acc (splitOn separator key) flat.${key})
    {}
    (builtins.attrNames flat);
  nestAttrs = nestAttrsWithSeparator "/";

  callTreeWithLib = lib: newScope: tree:
    lib.mapAttrs (
      _: value:
        if builtins.isAttrs value
        then lib.makeScope newScope (self: callTreeWithLib lib self.newScope value)
        else newScope {} value {}
    )
    tree;

  withSrc = src: {
    importTree = importTree src;
    importTreeWithDefaultFile = defaultFileName: importTreeWithDefaultFile defaultFileName src;
    importModules = importModules src;
    importModulesWithDefaultFile = defaultFileName: importModulesWithDefaultFile defaultFileName src;
    inherit nestAttrs nestAttrsWithSeparator;
  };

  overlay = src: final: prev:
    withSrc src
    // {
      callTree = callTreeWithLib final;
    };
}

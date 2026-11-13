{ lib, ... }:
let
  getFileNameWithoutExtension =
    file:
    let
      name = builtins.match "(.+)\\..+$" file;
    in
    builtins.elemAt name 0;

  # Lists the importable entries of a directory: every `*.nix` file except
  # `default.nix`, and every subdirectory that has a `default.nix`.
  dirEntries =
    dir:
    builtins.concatLists (
      lib.mapAttrsToList (
        path: kind:
        if kind == "directory" then
          let
            file = dir + "/${path}/default.nix";
          in
          lib.optional (builtins.pathExists file) {
            path = file;
            name = path;
            isDirectory = true;
          }
        else
          lib.optional (path != "default.nix" && lib.hasSuffix ".nix" path) {
            path = dir + "/${path}";
            name = getFileNameWithoutExtension path;
            isDirectory = false;
          }
      ) (builtins.readDir dir)
    );
  # modules/ is organised by feature: modules/<category>/<feature>/ holds one
  # file per platform (`nixos.nix`, `darwin.nix`, `home.nix`, or a
  # `<class>/default.nix` directory when a platform needs several files) and
  # a `common.nix` for what they share. A directory with none of those is a
  # (sub)category of features.
  classes = [
    "nixos"
    "darwin"
    "home"
  ];

  classFile =
    class: dir:
    if builtins.pathExists (dir + "/${class}.nix") then
      dir + "/${class}.nix"
    else if builtins.pathExists (dir + "/${class}/default.nix") then
      dir + "/${class}/default.nix"
    else
      null;

  isFeature =
    dir:
    lib.any (class: classFile class dir != null) classes || builtins.pathExists (dir + "/common.nix");

  # readDir's attribute names are sorted, so this is directory order.
  subdirs =
    dir: lib.attrNames (lib.filterAttrs (_: kind: kind == "directory") (builtins.readDir dir));

  # One platform's modules under a category, as name/module pairs in
  # directory order. A subcategory becomes one module importing its features.
  categoryEntries =
    class: dir:
    lib.concatMap (
      name:
      let
        sub = dir + "/${name}";
        file = classFile class sub;
        entries = categoryEntries class sub;
      in
      if isFeature sub then
        lib.optional (file != null) (lib.nameValuePair name file)
      else
        lib.optional (entries != [ ]) (lib.nameValuePair name { imports = map (e: e.value) entries; })
    ) (subdirs dir);

  makeCategory =
    class: dir:
    let
      entries = categoryEntries class dir;
    in
    lib.listToAttrs entries // { default.imports = map (e: e.value) entries; };
in
{
  importDir = dir: map (entry: entry.path) (dirEntries dir);

  importDirWithNames = dir: map (entry: { inherit (entry) path name; }) (dirEntries dir);

  # One platform's modules from modules/: each category as an attribute set
  # of its features plus `default` (the whole category), and top-level
  # features (hyprland, stylix) as plain modules. Only what has a file for
  # this platform appears.
  classModules =
    class: dir:
    lib.listToAttrs (
      lib.concatMap (
        name:
        let
          sub = dir + "/${name}";
          file = classFile class sub;
        in
        if isFeature sub then
          lib.optional (file != null) (lib.nameValuePair name file)
        else
          lib.optional (categoryEntries class sub != [ ]) (lib.nameValuePair name (makeCategory class sub))
      ) (subdirs dir)
    );

  # A feature's own sub-features for one platform, e.g. the skills module
  # importing every skill next to it.
  importFeatures = class: dir: map (e: e.value) (categoryEntries class dir);

  inherit getFileNameWithoutExtension;
}

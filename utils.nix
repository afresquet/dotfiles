{ lib, ... }:
let
  getFileNameWithoutExtension =
    file:
    let
      name = builtins.match "(.+)\\..+$" file;
    in
    builtins.elemAt name 0;

  importDirBase =
    {
      dir,
      names ? false,
    }:
    let
      dirEntries = builtins.readDir dir;

      mapDirEntries =
        path: kind:
        if kind == "directory" then
          let
            file = "${dir}/${path}/default.nix";
          in
          if builtins.pathExists file then [ file ] else [ ]
        else if path == "default.nix" then
          [ ]
        else
          [ "${dir}/${path}" ];

      mapDirEntriesWithNames =
        path: kind:
        if kind == "directory" then
          let
            file = {
              path = "${dir}/${path}/default.nix";
              name = path;
            };
          in
          if builtins.pathExists file.path then [ file ] else [ ]
        else
          let
            file = {
              path = "${dir}/${path}";
              name = getFileNameWithoutExtension path;
            };
          in
          if path == "default.nix" then [ ] else [ file ];

      mapFunction = if !names then mapDirEntries else mapDirEntriesWithNames;

      paths = lib.mapAttrsToList mapFunction dirEntries;
    in
    builtins.concatLists paths;
in
rec {
  importDir = dir: importDirBase { inherit dir; };

  importDirWithNames =
    dir:
    importDirBase {
      inherit dir;
      names = true;
    };

  importDirAsAttrSet =
    {
      dir,
      args ? null,
    }:
    let
      moduleFiles = importDirWithNames dir;

      mapModuleFiles =
        { name, path }:
        let
          derivation = if args != null then import path args else import path;
        in
        {
          ${name} = derivation;
        };

      modules = builtins.map mapModuleFiles moduleFiles;
    in
    lib.mergeAttrsList modules;

  inherit getFileNameWithoutExtension;
}

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
in
rec {
  importDir = dir: map (entry: entry.path) (dirEntries dir);

  importDirWithNames = dir: map (entry: { inherit (entry) path name; }) (dirEntries dir);

  # Directory entries as an attribute set keyed by file or directory name.
  # Subdirectories are imported with `args` (they are categories built with
  # `makeCategory`); plain files are returned as paths, so they are ordinary
  # modules with no wrapper lambda.
  importDirAsAttrSet =
    {
      dir,
      args ? null,
    }:
    lib.listToAttrs (
      map (
        entry:
        lib.nameValuePair entry.name (
          if entry.isDirectory && args != null then import entry.path args else entry.path
        )
      ) (dirEntries dir)
    );

  makeCategory =
    dir:
    importDirAsAttrSet { inherit dir; }
    // {
      default = {
        imports = importDir dir;
      };
    };

  inherit getFileNameWithoutExtension;
}

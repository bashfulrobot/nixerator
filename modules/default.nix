# Auto-import all modules in this directory tree.
#
# Uses denful/import-tree (via `inputs.import-tree`) instead of a hand-rolled
# recursive importer. The `.filterNot` chain reproduces the legacy exclusion
# set (disabled/build/cfg/reference) so subdirectories holding local helpers
# stay opt-out without renaming them. The exclusion of `/default.nix` skips
# this dispatcher file itself; nested `default.nix` files (with a directory
# prefix) are still picked up.
#
# Paths passed to the filter are root-relative (e.g. `/apps/cli/foo.nix`),
# matching import-tree's internal convention.
{ inputs, lib, ... }:

let
  isExcluded =
    path:
    let
      s = toString path;
    in
    s == "/default.nix"
    || lib.hasInfix "/disabled/" s
    || lib.hasInfix "/build/" s
    || lib.hasInfix "/cfg/" s
    || lib.hasInfix "/reference/" s;
in
(inputs.import-tree.filterNot isExcluded) ./.

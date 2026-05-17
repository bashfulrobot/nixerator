# Auto-import every webapp module in this directory. Mirrors the exclusion
# set from `modules/default.nix` so local `build/`, `cfg/`, `reference/`, or
# `disabled/` directories stay opt-out, and this dispatcher file is excluded
# from its own import list.
#
# Paths passed to the filter are root-relative.
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

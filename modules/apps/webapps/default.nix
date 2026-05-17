# Auto-import every webapp module in this directory. Mirrors the exclusion
# set from `modules/default.nix` so local `build/`, `cfg/`, `reference/`, or
# `disabled/` directories stay opt-out, and this dispatcher file is excluded
# from its own import list.
#
# Self-exclusion checks both the root-relative form `/default.nix` (current
# import-tree convention) and the absolute path of this file, so the guard
# survives an upstream change in how paths are relativized.
{ inputs, lib, ... }:

let
  selfAbsolute = toString ./default.nix;

  # Same rationale as `modules/default.nix`: two exact-match branches,
  # no `hasSuffix` branch — the suffix would over-match a legitimate
  # nested module named `webapps/default.nix`.
  isSelf = s: s == "/default.nix" || s == selfAbsolute;

  isExcluded =
    path:
    let
      s = toString path;
    in
    isSelf s
    || lib.hasInfix "/disabled/" s
    || lib.hasInfix "/build/" s
    || lib.hasInfix "/cfg/" s
    || lib.hasInfix "/reference/" s;
in
(inputs.import-tree.filterNot isExcluded) ./.

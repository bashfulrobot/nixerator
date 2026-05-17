# Auto-import all modules in this directory tree.
#
# Uses denful/import-tree (via `inputs.import-tree`) instead of a hand-rolled
# recursive importer. The `.filterNot` chain reproduces the legacy exclusion
# set (disabled/build/cfg/reference) so subdirectories holding local helpers
# stay opt-out without renaming them. The self-match (`isSelf`) skips this
# dispatcher file so import-tree does not recurse into itself; nested
# `default.nix` files (with a directory prefix) are still picked up.
#
# import-tree's current convention passes the predicate root-relative paths
# (e.g. `/apps/cli/foo.nix`, and `/default.nix` for the dispatcher). To stay
# robust against an upstream change in relativization, `isSelf` also matches
# the absolute path of this file (`toString ./default.nix`). The default
# import-tree filter additionally drops anything containing `/_`, which is
# the upstream opt-out convention if a future helper wants it.
{ inputs, lib, ... }:

let
  selfAbsolute = toString ./default.nix;

  # Two exact-match branches: import-tree's current convention is the
  # root-relative form, the absolute form is a fallback if upstream ever
  # changes that convention. We deliberately do NOT use a `hasSuffix`
  # branch — a stray `apps/foo/modules/default.nix` somewhere in the tree
  # would otherwise be silently dropped from `imports`.
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

# Auto-import all modules in this directory tree
{ lib, ... }:

let
  autoImportLib = import ../lib/autoimport.nix { inherit lib; };
in
autoImportLib.simpleAutoImport ./.

{ lib, ... }:

let
  autoImportLib = import ../../../lib/autoimport.nix { inherit lib; };
in
autoImportLib.simpleAutoImport ./.

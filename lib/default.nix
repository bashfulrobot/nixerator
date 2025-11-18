{ inputs, ... }:

let
  # Import host creation function
  hostLib = import ./mkHost.nix { inherit inputs; };
in
{
  # Export mkHost function
  inherit (hostLib) mkHost;
}

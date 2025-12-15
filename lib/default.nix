{ inputs, secrets, ... }:

let
  # Import host creation function
  hostLib = import ./mkHost.nix { inherit inputs secrets; };
in
{
  # Export mkHost function
  inherit (hostLib) mkHost;
}

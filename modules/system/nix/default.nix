{ lib, ... }:

let
  secrets = builtins.fromJSON (builtins.readFile ../../../secrets/secrets.json);
in

{

  nix = {
    nixPath = [ ];

    settings = {
      substituters = [
        "https://hyprland.cachix.org"
        "https://cache.numtide.com"
      ];

      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    }
    // lib.optionalAttrs ((secrets.github.accessToken or null) != null) {
      access-tokens = "github.com=${secrets.github.accessToken}";
    };
  };
}

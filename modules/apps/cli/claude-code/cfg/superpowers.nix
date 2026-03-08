{
  lib,
  pkgs,
  versions,
}:

let
  src = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = versions.cli.superpowers.rev;
    hash = versions.cli.superpowers.hash;
  };

  # Discover all subdirectories under a path
  subdirs = path: lib.filterAttrs (_: type: type == "directory") (builtins.readDir path);

  # Discover all .md files under a path (strip extension for attr name)
  mdFiles =
    path:
    lib.filterAttrs (_: type: type == "regular") (
      lib.mapAttrs' (
        name: type:
        if lib.hasSuffix ".md" name then
          {
            name = lib.removeSuffix ".md" name;
            value = type;
          }
        else
          {
            inherit name;
            value = type;
          }
      ) (builtins.readDir path)
    );
in
{
  # Skills -- each subdir becomes "superpowers:<name>"
  skills = lib.mapAttrs' (name: _: {
    name = "superpowers:${name}";
    value = "${src}/skills/${name}";
  }) (subdirs "${src}/skills");

  # Agents -- each .md file becomes an agent
  agents = lib.mapAttrs' (name: _: {
    inherit name;
    value = builtins.readFile "${src}/agents/${name}.md";
  }) (mdFiles "${src}/agents");

  # Commands -- each .md file becomes a command
  commands = lib.mapAttrs' (name: _: {
    inherit name;
    value = builtins.readFile "${src}/commands/${name}.md";
  }) (mdFiles "${src}/commands");
}

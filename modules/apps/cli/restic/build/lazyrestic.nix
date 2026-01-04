{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "lazyrestic";
  version = "unstable-2025-12-30";

  src = fetchFromGitHub {
    owner = "craigderington";
    repo = "lazyrestic";
    rev = "b59e26f06da7b35f587b97cf0804b0e66b78f1e1";
    hash = "sha256-Uezahy0f1/3wnuYQscXgpb0iFXWTvP0I1V5TPcmrV3A=";
  };

  vendorHash = "sha256-MIq04ecsWq2DEbt6myCm4VqQYqjlAmTScDv0OXm9XV4=";

  # Skip tests due to filesystem-specific test dependencies
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A TUI for managing restic backups";
    homepage = "https://github.com/craigderington/lazyrestic";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "lazyrestic";
  };
}

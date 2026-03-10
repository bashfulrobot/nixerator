{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "termly-trigger";
  version = "0.1.0";

  src = ./trigger;

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "HTTP trigger server for remote termly session control";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "termly-trigger";
  };
}

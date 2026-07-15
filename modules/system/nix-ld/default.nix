{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system.nix-ld;
in
{
  options = {
    system.nix-ld.enable = lib.mkEnableOption ''
      nix-ld, a stub loader that lets unpatched, dynamically-linked "foreign"
      binaries run on NixOS. Needed for tools that fetch prebuilt manylinux
      wheels at run time -- notably uv/pip Python environments whose native
      extensions (numpy, onnxruntime, torch via sentence-transformers, ...)
      dlopen libstdc++ and friends. With nix-ld enabled and uv's managed
      interpreter, those wheels resolve their libraries process-wide via
      NIX_LD_LIBRARY_PATH instead of failing with "libstdc++.so.6: cannot open
      shared object file". Drives the kongdex (kong-docs) MCP server, which is a
      local uv-run RAG stack over the Kong docs
    '';
  };

  config = lib.mkIf cfg.enable {
    programs.nix-ld = {
      enable = true;
      # Libraries the loader exposes to foreign binaries. The first two are
      # verified sufficient for the kongdex ML stack (numpy / onnxruntime /
      # chromadb / sentence-transformers all import with just these); openssl
      # and zstd cover the wider data-science wheel set (grpc, pyarrow) so new
      # projects do not each need a fresh round of missing-lib debugging.
      libraries = with pkgs; [
        stdenv.cc.cc.lib # libstdc++.so.6, libgcc_s, libgomp
        zlib # libz
        openssl # libssl / libcrypto
        zstd # libzstd
      ];
    };
  };
}

{ pkgs, versions }:

pkgs.fetchzip {
  url = "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip";
  hash = versions.gui.vocalinux.modelHash;
}

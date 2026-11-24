{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.artcraft;
in
{
  options = {
    apps.gui.artcraft.enable = lib.mkEnableOption "ArtCraft open-source Craft apps (PhotoCraft, VectorCraft, LightCraft, PdfCraft)";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # keep-sorted start case=no numeric=yes
      lightcraft # photo library + raw development, Lightroom-style
      pdfcraft # PDF reading, organizing, securing
      photocraft # layered image editor, Photoshop-style (PSD/PSB)
      vectorcraft # vector illustration, Illustrator-style (SVG/PDF)
      # keep-sorted end

      # Also in nixpkgs, deliberately not installed (add above to enable):
      #   filmcraft   video editor, Premiere-style
      #   soundcraft  desktop audio app
      #   wordcraft   word processor (DOCX/ODT/RTF)
      #   deckcraft   presentations (PPTX)
      #   cadcraft    2D drafting (DXF/DWG)
      #   gridcraft   spreadsheets (XLSX/CSV/TSV)
      # Not in nixpkgs yet: effectcraft (nixpkgs#571432), designcraft
      # (nixpkgs#571440); anicraft, figcraft, texturecraft, materialcraft and
      # ArtCraft Studio are unpackaged. Upstream: https://getartcraft.com/linux
    ];
  };
}

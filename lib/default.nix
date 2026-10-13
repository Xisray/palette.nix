{lib}: let
  schema = import ./schema.nix {inherit lib;};
  template = import ./template.nix {inherit lib;};
  palette = import ./palette.nix ({inherit lib;} // schema // template);
in {
  inherit (palette) mkPalette;
}

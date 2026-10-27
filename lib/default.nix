{lib}: let
  schema = import ./schema.nix {inherit lib;};
  template = import ./template.nix {inherit lib;};
  parseYaml = import ./yaml.nix {inherit lib;};
  source = import ./source.nix {
    inherit lib parseYaml;
    inherit (schema) base16Names base24Names roleNames defaultRoles;
  };
  palette = import ./palette.nix {
    inherit lib;
    inherit (schema) mkValidate roleNames semanticNames fillBase24 overridableNames;
    inherit (template) mkRender defaultName;
    inherit (source) loadSource;
  };
in {
  inherit (palette) mkPalette;
  inherit parseYaml;
}

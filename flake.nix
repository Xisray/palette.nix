{
  description = "Palette library: validated colors, base16 mapping and template rendering";

  inputs.nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

  outputs = {nixpkgs-lib, ...}: {
    lib = import ./lib {inherit (nixpkgs-lib) lib;};
  };
}

{
  lib,
  mkValidate,
  roleNames,
  semanticNames,
  fillBase24,
  mkRender,
  defaultName,
}: let
  inherit (builtins) substring isBool;

  digits = lib.stringToCharacters "0123456789abcdef";
  hexVal = c: lib.lists.findFirstIndex (d: d == c) null digits;
  byteAt = hex: i:
    16 * hexVal (substring (2 * i) 1 hex) + hexVal (substring (2 * i + 1) 1 hex);

  stripHash = s: lib.toLower (lib.removePrefix "#" s);

  colorVariants = hex: let
    p = i: substring (2 * i) 2 hex;
    d = i: toString (byteAt hex i);
    f = i: toString (byteAt hex i / 255.0);
  in {
    "" = hex;
    "-hex" = hex;
    "-hash" = "#${hex}";
    "-hex-bgr" = p 2 + p 1 + p 0;
    "-hex-r" = p 0;
    "-hex-g" = p 1;
    "-hex-b" = p 2;
    "-rgb-r" = d 0;
    "-rgb-g" = d 1;
    "-rgb-b" = d 2;
    "-dec-r" = f 0;
    "-dec-g" = f 1;
    "-dec-b" = f 2;
    "-rgb" = "rgb(${d 0}, ${d 1}, ${d 2})";
    "-rgb-csv" = "${d 0},${d 1},${d 2}";
  };

  expand = colors:
    lib.concatMapAttrs (
      name: raw:
        lib.mapAttrs' (suffix: value: lib.nameValuePair (name + suffix) value)
        (colorVariants (stripHash raw))
    )
    colors;

  stringify = v:
    if isBool v
    then
      (
        if v
        then "true"
        else "false"
      )
    else toString v;

  mkPalette = palette: let
    checked = mkValidate palette;
    base = fillBase24 (removeAttrs checked roleNames);
    colors =
      base
      // lib.mapAttrs (_: key: base.${key}) semanticNames
      // lib.genAttrs roleNames (role: base.${checked.${role}});
    strings = expand colors;
    vars = lib.mapAttrsToList (name: value: {inherit name value;}) strings;
    withVariables = variables:
      lib.mapAttrsToList (name: value: {
        inherit name;
        value = stringify value;
      })
      variables
      ++ vars;

    render = {
      src,
      variables ? {},
      strict ? true,
    }:
      mkRender (withVariables variables) strict src;
    renderFile = {
      src,
      name ? null,
      ext ? null,
      strict ? true,
      variables ? {},
    }: let
      baseName =
        if name != null
        then name
        else defaultName src;
      fileName = baseName + lib.optionalString (ext != null) ".${ext}";
    in
      builtins.toFile
      (lib.strings.sanitizeDerivationName fileName)
      (mkRender (withVariables variables) strict src);
  in
    strings
    // {
      withHashtag = lib.mapAttrs (_: s: "#" + stripHash s) colors;
      inherit render renderFile;
      __functor = _: {
        src,
        name ? null,
        ext ? null,
        strict ? true,
        variables ? {},
        file ? true,
      }:
        if file
        then renderFile {inherit src name ext strict variables;}
        else render {inherit src strict variables;};
    };
in {
  inherit mkPalette;
}

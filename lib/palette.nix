{
  lib,
  mkValidate,
  roleNames,
  semanticNames,
  fillBase24,
  overridableNames,
  loadSource,
  mkRender,
  defaultName,
}: let
  inherit (builtins) substring isBool isAttrs attrNames filter elem concatStringsSep;

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

  checkOverrides = o: let
    keys = attrNames o;
    semantic = filter (k: semanticNames ? ${k}) keys;
    unknown = filter (k: !(elem k overridableNames) && !(semanticNames ? ${k})) keys;
  in
    if !isAttrs o
    then throw "palette: overrides must be an attrset, got: ${builtins.typeOf o}"
    else if semantic != []
    then throw "palette: semantic color(s) cannot be overridden: ${concatStringsSep ", " semantic} (override the base color they follow instead, e.g. red -> base08)"
    else if unknown != []
    then throw "palette: unknown override(s): ${concatStringsSep ", " unknown} (allowed: ${concatStringsSep ", " overridableNames})"
    else o;

  # raw — «сырая» схема (attrset base*/роли). Результат умеет пересобираться
  # с переопределениями: `.overrides {...}` или просто вызов `palette {...}`.
  build = raw: let
    checked = mkValidate raw;
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
    callRender = {
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
  in
    strings
    // {
      withHashtag = lib.mapAttrs (_: s: "#" + stripHash s) colors;
      inherit render renderFile;
      overrides = o: build (raw // checkOverrides o);
      __functor = self: args:
        # аргументы с `src` — рендер шаблона, иначе — переопределения цветов
        if args ? src
        then callRender args
        else self.overrides args;
    };

  # mkPalette {схема}                      — как раньше
  # mkPalette ./scheme.yaml | ./scheme.json — схема из файла
  # mkPalette ./scheme.yaml {primary = "base12";}  — с переопределениями
  mkPalette = src: build (loadSource src);
in {
  inherit mkPalette;
}

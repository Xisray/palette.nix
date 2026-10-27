{lib}: let
  inherit (builtins) concatStringsSep isString match isAttrs attrNames filter deepSeq elem;
  isColorString = s: match "#?[0-9a-fA-F]{6}" s != null;

  color = {kind = "color";};
  enum = values: {
    kind = "enum";
    inherit values;
  };
  struct = fields: {
    kind = "struct";
    inherit fields;
  };
  optional = ty: ty // {optional = true;};

  hexDigits = lib.stringToCharacters "0123456789ABCDEF";
  base16Names = map (d: "base0${d}") hexDigits;
  base24Names = map (d: "base1${d}") (lib.take 8 hexDigits);

  accentNames = lib.drop 7 base16Names ++ lib.drop 2 base24Names;

  roleNames = ["primary" "secondary" "tertiary"];

  # Роли по умолчанию для схем из файла (в tinted-theming их нет).
  defaultRoles = {
    primary = "base0D";
    secondary = "base0E";
    tertiary = "base0B";
  };

  semanticNames = {
    red = "base08";
    pink = "base12"; # bright red
    orange = "base09";
    yellow = "base0A";
    lemon = "base13"; # bright yellow
    green = "base0B";
    lime = "base14"; # bright green
    cyan = "base0C";
    aqua = "base15"; # bright cyan
    blue = "base0D";
    sky = "base16"; # bright blue
    magenta = "base0E";
    violet = "base17"; # bright magenta
    brown = "base0F";
  };

  fillBase24 = p:
    p
    // {
      base10 = p.base10 or p.base00;
      base11 = p.base11 or p.base00;
      base12 = p.base12 or p.base08;
      base13 = p.base13 or p.base0A;
      base14 = p.base14 or p.base0B;
      base15 = p.base15 or p.base0C;
      base16 = p.base16 or p.base0D;
      base17 = p.base17 or p.base0E;
    };

  paletteType = struct (
    lib.genAttrs base16Names (_: color)
    // lib.genAttrs base24Names (_: optional color)
    // lib.genAttrs roleNames (_: enum accentNames)
  );

  showPath = path:
    if path == []
    then "<root>"
    else concatStringsSep "." path;

  describe = ty:
    if ty.kind == "color"
    then "hex color"
    else "attrset";

  validate = path: ty: value:
    if ty.kind == "color"
    then
      if isString value && isColorString value
      then value
      else throw "palette: '${showPath path}' must be a hex color (#rrggbb), got: ${builtins.toJSON value}"
    else if ty.kind == "enum"
    then
      if isString value && elem value ty.values
      then value
      else throw "palette: '${showPath path}' must be one of: ${concatStringsSep ", " ty.values}; got: ${builtins.toJSON value}"
    else if !isAttrs value
    then throw "palette: '${showPath path}' must be an ${describe ty}, got: ${builtins.typeOf value}"
    else let
      known = attrNames ty.fields;
      unknown = filter (k: !(ty.fields ? ${k})) (attrNames value);
      missing = filter (k: !(ty.fields.${k}.optional or false) && !(value ? ${k})) known;
    in
      if unknown != []
      then throw "palette: unknown key(s) in '${showPath path}': ${concatStringsSep ", " unknown} (allowed: ${concatStringsSep ", " known})"
      else if missing != []
      then throw "palette: missing required key(s) in '${showPath path}': ${concatStringsSep ", " missing}"
      else lib.mapAttrs (k: v: validate (path ++ [k]) ty.fields.${k} v) value;

  mkValidate = palette: let
    v = validate [] paletteType palette;
  in
    deepSeq v v;

  # Что можно переопределять: все base и роли (семантические имена — нельзя).
  overridableNames = base16Names ++ base24Names ++ roleNames;
in {
  inherit
    mkValidate
    roleNames
    defaultRoles
    semanticNames
    fillBase24
    base16Names
    base24Names
    overridableNames
    ;
}

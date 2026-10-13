{lib}: let
  inherit (builtins) isPath isAttrs readFile head filter isList split concatStringsSep;
  readSrc = src:
    if isPath src || (isAttrs src && src ? outPath)
    then readFile src
    else src;

  mkRender = vars: strict: src: let
    text = readSrc src;
    keys = map (v: v.name) vars;
    vals = map (v: v.value) vars;
    out =
      lib.replaceStrings
      (map (k: "{{${k}}}") keys ++ map (k: "{{ ${k} }}") keys)
      (vals ++ vals)
      text;
    leftovers = map head (filter isList (split "([{][{][^}]*[}][}])" out));
  in
    if strict && leftovers != []
    then throw "palette: unknown template variable(s): ${concatStringsSep ", " (lib.unique leftovers)}"
    else out;

  defaultName = src: let
    raw =
      if isPath src
      then baseNameOf src
      else if isAttrs src && src ? outPath
      then src.name or ""
      else "";
    stripped = lib.replaceStrings [".mustache" "mustache"] ["" ""] raw;
  in
    if stripped == ""
    then "palette"
    else stripped;
in {
  inherit mkRender defaultName;
}

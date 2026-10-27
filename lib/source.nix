{
  lib,
  parseYaml,
  base16Names,
  base24Names,
  roleNames,
  defaultRoles,
}: let
  inherit (builtins) isAttrs isPath isString readFile fromJSON match elem;

  known = base16Names ++ base24Names ++ roleNames;
  pick = lib.filterAttrs (k: _: elem k known);

  isFileSource = src: isPath src || isString src || (isAttrs src && src ? outPath);

  isJson = src: match ".*\\.[jJ][sS][oO][nN]" (toString src) != null;

  readDocument = src: let
    text = readFile src;
    doc =
      if isJson src
      then fromJSON text
      else parseYaml text;
  in
    if isAttrs doc
    then doc
    else throw "palette: '${toString src}' must contain a mapping at the top level";

  # Схема в формате tinted-theming (`palette: { base00: ... }`) или «плоская»
  # (`base00: ...` на верхнем уровне). Остальные ключи (system, name, author,
  # variant, ...) игнорируются. Роли можно задать на верхнем уровне или внутри
  # palette; если их нет — берутся defaultRoles.
  fromDocument = doc: let
    pal =
      if doc ? palette && isAttrs doc.palette
      then doc.palette
      else doc;
  in
    defaultRoles // pick doc // pick pal;

  # Принимает либо attrset (как раньше), либо путь/строку/outPath на yaml|json.
  loadSource = src:
    if isFileSource src
    then fromDocument (readDocument src)
    else if isAttrs src
    then src
    else throw "palette: expected an attrset or a path to a yaml/json file, got: ${builtins.typeOf src}";
in {
  inherit loadSource;
}

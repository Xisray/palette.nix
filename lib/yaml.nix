/*
  Минимальный YAML-парсер на Nix (нужен только `lib`).

  Поддерживает:
    - вложенные attrset по отступам (`key:` + дочерние строки с бо́льшим отступом)
    - значения в "двойных" и 'одинарных' кавычках, обычные (plain) строки
    - комментарии (`# ...` отдельной строкой и после значения)
    - пустые строки, CRLF

  Не поддерживает: списки, многострочные строки, якоря, `---`, типизацию
  (числа/булевы остаются строками). Для схем base16/base24 этого достаточно.
*/
{lib}: text: let
  inherit (lib) filter elemAt length splitString replaceStrings stringLength;

  isBlank = line: builtins.match "[[:space:]]*(#.*)?" line != null;

  unescapeDouble =
    replaceStrings [''\"'' ''\\'' ''\n'' ''\t''] [''"'' ''\'' "\n" "\t"];

  parseScalar = raw: let
    dq = builtins.match ''"(([^"\\]|\\.)*)"[[:space:]]*(#.*)?'' raw;
    sq = builtins.match "'([^']*)'[[:space:]]*(#.*)?" raw;
    noComment = builtins.match "(.*[^[:space:]])[[:space:]]+#.*" raw;
    trimmed = builtins.match "[[:space:]]*(.*[^[:space:]])[[:space:]]*" raw;
  in
    if dq != null
    then unescapeDouble (elemAt dq 0)
    else if sq != null
    then elemAt sq 0
    else if noComment != null
    then elemAt noComment 0
    else if trimmed != null
    then elemAt trimmed 0
    else "";

  # Строка -> { indent, key, value }; value = null, если после `key:` пусто.
  parseLine = line: let
    m = builtins.match "( *)([^:#[:space:]][^:]*):[[:space:]]*(.*)" line;
  in
    if m == null
    then throw "palette: yaml: cannot parse line: ${line}"
    else {
      indent = stringLength (elemAt m 0);
      key = elemAt m 1;
      value =
        if isBlank (elemAt m 2)
        then null
        else parseScalar (elemAt m 2);
    };

  lines = map parseLine (filter (l: !(isBlank l)) (splitString "\n" text));
  n = length lines;

  # Читает ключи одного уровня, начиная со строки i0, пока отступ >= indent.
  # Возвращает { value; next } (next — индекс первой необработанной строки).
  # Список читается только через elemAt (O(1)), поэтому разбор линейный.
  parseBlock = indent: i0: let
    go = acc: i:
      if i >= n || (elemAt lines i).indent < indent
      then {
        value = acc;
        next = i;
      }
      else let
        l = elemAt lines i;
        hasChildren =
          l.value == null && i + 1 < n && (elemAt lines (i + 1)).indent > l.indent;
        sub = parseBlock (elemAt lines (i + 1)).indent (i + 1);
      in
        if hasChildren
        then go (acc // {${l.key} = sub.value;}) sub.next
        else go (acc // {${l.key} = l.value;}) (i + 1);
  in
    go {} i0;
in
  if n == 0
  then {}
  else (parseBlock (elemAt lines 0).indent 0).value

#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
codex_dir="$HOME/.codex"
manifest_dir="$codex_dir/sage"
manifest="$manifest_dir/manifest"
config_file="$codex_dir/config.toml"
shopt -s nullglob
usage() {
  cat <<USAGE
Usage: $(basename "$0") install [--dev] [--activate]
       $(basename "$0") uninstall
       $(basename "$0") --help

Install Sage into ~/.codex. Use --dev to link skills and model instructions.
Use --activate to select Sage in the top-level config.toml. Activation is optional and
uninstall restores the prior setting only when it still selects Sage.
USAGE
}
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi
command="$1"
shift
case "$command" in
  --help|-h)
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 2
    fi
    usage
    exit 0
    ;;
  install)
    mode=copy
    activate=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --dev) mode=dev ;;
        --activate) activate=true ;;
        *) echo "Unknown install argument: $1" >&2; exit 2 ;;
      esac
      shift
    done
    ;;
  uninstall)
    if [[ $# -ne 0 ]]; then
      echo "Unknown argument: $1" >&2
      exit 2
    fi
    mode=uninstall
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
hash_file() {
  sha256sum "$1" | awk '{print $1}'
}
hash_path() {
  local p=$1 rel target digest
  if [[ -f $p && ! -L $p ]]; then
    hash_file "$p"
    return
  fi
  find -P "$p" -mindepth 1 -print0 |
  while IFS= read -r -d '' rel; do
      rel=${rel#"$p/"}
      if [[ -L "$p/$rel" ]]; then
        target=$(readlink "$p/$rel") || return 1
        printf 'l\t%s\t%s\n' "$rel" "$target"
      elif [[ -d "$p/$rel" ]]; then
        printf 'd\t%s\n' "$rel"
      else
        if [[ -f "$p/$rel" ]]; then
          digest=$(sha256sum "$p/$rel" | awk '{print $1}') || return 1
          printf 'f\t%s\t%s\n' "$rel" "$digest"
        else
          echo "Unsupported tree entry: $p/$rel" >&2
          return 1
        fi
      fi
  done | sort | sha256sum | awk '{print $1}'
}
record() {
  local p=$1 k=$2 v=$3 tmp
  tmp=$(mktemp)
  if [[ -f $manifest ]]; then
    awk -F '\t' -v p="$p" '$1 != p' "$manifest" > "$tmp"
  fi
  printf '%s\t%s\t%s\n' "$p" "$k" "$v" >> "$tmp"
  mv "$tmp" "$manifest"
}
safe_parent() {
  local p=$1 parent
  parent=$(dirname "$p")
  while [[ $parent != / && $parent != . ]]; do
    if [[ -L $parent ]]; then
      echo "Refusing symlinked destination parent: $parent" >&2
      return 1
    fi
    if [[ -e $parent && ! -d $parent ]]; then
      echo "Refusing non-directory destination parent: $parent" >&2
      return 1
    fi
    parent=$(dirname "$parent")
  done
  return 0
}

validate_manifest_location() {
  safe_parent "$manifest" || return 1
  if [[ -L $codex_dir ]]; then
    echo "Refusing symlinked codex directory: $codex_dir" >&2
    return 1
  fi
  if [[ -L $manifest_dir ]]; then
    echo "Refusing symlinked manifest directory: $manifest_dir" >&2
    return 1
  fi
  if [[ -L $manifest ]]; then
    echo "Refusing symlinked manifest: $manifest" >&2
    return 1
  fi
  if [[ -e $manifest && ! -f $manifest ]]; then
    echo "Refusing non-file manifest: $manifest" >&2
    return 1
  fi
  return 0
}

validate_manifest_location

valid_manifest_entry() {
  local p=$1 k=$2 v=$3 rest
  if [[ $p == __MODE__ ]]; then
    [[ $k == mode && ( $v == copy || $v == dev ) ]]
    return
  fi
  if [[ $p == __ACTIVATION__ ]]; then
    [[ $k == state && ( $v == absent || $v == present:* ) ]]
    return
  fi
  [[ -n $v ]] || return 1
  if [[ $p == "$codex_dir/skills/"* ]]; then
    rest=${p#"$codex_dir/skills/"}
    [[ $rest != */* && $rest != . && $rest != .. && -n $rest ]] || return 1
  elif [[ $p == "$codex_dir/agents/"* ]]; then
    rest=${p#"$codex_dir/agents/"}
    [[ $rest != */* && $rest == *.toml && -n $rest ]] || return 1
  elif [[ $p == "$codex_dir/model-instructions/sage.md" ]]; then
    :
  else
    return 1
  fi
  [[ $k == file || $k == tree || $k == link ]]
}

config_safe() {
  if [[ -L $config_file || ( -e $config_file && ! -f $config_file ) ]]; then
    echo "Refusing unsafe config path: $config_file" >&2
    return 1
  fi
}
config_scan() {
  local action=$1 file=${2:-$config_file}
  python3 - "$action" "$file" "${3:-absent}" <<'PY'
import sys, json, os, tempfile, stat, base64
action, path, saved_arg = sys.argv[1:]
if os.path.islink(path): raise SystemExit(2)
if not os.path.exists(path):
    lines = []
    if action == 'state': print('absent'); raise SystemExit(0)
    if action == 'sage' or action == 'restore': raise SystemExit(1 if action == 'sage' else 0)
if os.path.exists(path) and (os.path.islink(path) or not os.path.isfile(path)): raise SystemExit(2)
def clean_root_line(line):
    q = None; esc = False; stack = []
    for i, ch in enumerate(line):
        if q == '"' and esc: esc = False; continue
        if q == '"' and ch == '\\': esc = True; continue
        if q:
            if ch == q: q = None
            continue
        if ch in ('"', "'"):
            if i + 2 < len(line) and line[i:i+3] == ch * 3: raise ValueError()
            q = ch; continue
        if ch == '#':
            if stack: raise ValueError()
            return line[:i]
        if ch in '[{': stack.append(ch)
        elif ch in ']}':
            if not stack or (ch == ']' and stack[-1] != '[') or (ch == '}' and stack[-1] != '{'): raise ValueError()
            stack.pop()
    if q or stack: raise ValueError()
    return line
def parse_value(right):
    right = right.strip()
    if len(right) < 2 or right.startswith('"""') or right.startswith("'''") or right[0] not in ('"', "'") or right[-1] != right[0]: raise ValueError()
    if right[0] == "'" and "'" in right[1:-1]: raise ValueError()
    value = json.loads(right) if right.startswith('"') else right[1:-1]
    if not isinstance(value, str): raise ValueError()
    return value
found = None
if os.path.exists(path): lines = open(path, encoding='utf-8', newline='').read().splitlines(True)
matched = None
for n, raw in enumerate(lines):
    raw_line = raw.rstrip('\r\n')
    line = raw_line
    if line.lstrip().startswith('['): break
    try: line = clean_root_line(line)
    except ValueError: raise SystemExit(2)
    stripped = line.strip()
    if not stripped: continue
    left, sep, right = line.partition('=')
    if not sep: raise SystemExit(2)
    if 'model_instructions_file' in left and left.strip() != 'model_instructions_file': raise SystemExit(2)
    if left.strip() != 'model_instructions_file': continue
    if found is not None: raise SystemExit(2)
    try:
        value = parse_value(right)
    except Exception: raise SystemExit(2)
    found = (raw_line, value)
    matched = n
if action == 'state': print('absent' if found is None else 'present:' + found[0])
elif action == 'sage': raise SystemExit(0 if found and found[1] == '~/.codex/model-instructions/sage.md' else 1)
elif action in ('activate', 'restore'):
    if action == 'restore' and (not found or found[1] != '~/.codex/model-instructions/sage.md'): raise SystemExit(0)
    saved = sys.argv[3] if len(sys.argv) > 3 else 'absent'
    if action == 'restore' and saved != 'absent':
        try: saved = base64.b64decode(saved, validate=True).decode()
        except Exception: raise SystemExit(2)
        if '\n' in saved or '\r' in saved: raise SystemExit(2)
        try: saved_clean = clean_root_line(saved)
        except ValueError: raise SystemExit(2)
        sl, ss, sv = saved_clean.partition('=')
        if not ss or sl.strip() != 'model_instructions_file': raise SystemExit(2)
        try: parse_value(sv)
        except Exception: raise SystemExit(2)
    ending = lines[matched][len(lines[matched].rstrip('\r\n')):] if matched is not None else '\n'
    replacement = 'model_instructions_file = "~/.codex/model-instructions/sage.md"' + ending
    if action == 'restore' and saved != 'absent': replacement = saved + ending
    if matched is None: lines.insert(0, replacement)
    elif action == 'restore' and saved == 'absent': del lines[matched]
    else: lines[matched] = replacement
    def write_config(text):
        fd, tmp = tempfile.mkstemp(prefix='.config.toml.', dir=os.path.dirname(path))
        try:
            with os.fdopen(fd, 'w', encoding='utf-8', newline='') as out:
                if os.path.exists(path): os.fchmod(out.fileno(), stat.S_IMODE(os.stat(path).st_mode))
                out.write(text)
            os.replace(tmp, path); tmp = None
        except Exception as exc:
            print('config write failed: ' + str(exc), file=sys.stderr); raise SystemExit(2)
        finally:
            if tmp and os.path.exists(tmp): os.unlink(tmp)
    write_config(''.join(lines))
else: raise SystemExit(2)
PY
}
config_rewrite() {
  config_safe || return 1
  config_scan "$1" "$config_file"
}
config_state() {
  config_safe || return 1
  config_scan state "$config_file"
}
config_restore() {
  config_safe || return 1
  config_scan restore "$config_file" "$1"
}

if [[ $mode == uninstall ]]; then
  if [[ ! -f $manifest ]]; then
    echo "No Sage installation manifest found."
    echo "Sage uninstall complete."
    exit 0
  fi
  tmp_manifest="$(mktemp)"
  while IFS=$'\t' read -r path kind value; do
    [[ $path && $path != '#'* ]] || continue
    if ! valid_manifest_entry "$path" "$kind" "$value"; then
      echo "Invalid manifest entry: $path" >&2
      exit 1
    fi
  done < "$manifest"
  activation_saved=''
  while IFS=$'\t' read -r path kind value; do
    [[ $path == __ACTIVATION__ ]] && activation_saved=$value
  done < "$manifest"
  if [[ -n $activation_saved ]]; then
    current_state=$(config_state) || exit 1
    if config_scan sage "$config_file"; then
      if [[ $activation_saved == present:* ]]; then activation_saved=${activation_saved#present:}; fi
      if ! config_restore "$activation_saved"; then
        echo "Sage config restoration failed. Retry uninstall after fixing config.toml." >&2
        exit 1
      fi
    else
      echo "Preserved user-changed config.toml"
    fi
  fi
  while IFS=$'\t' read -r path kind value; do
    [[ $path && $path != '#'* ]] || continue
    if [[ $path == __ACTIVATION__ ]]; then
      continue
    fi
    if [[ $path == __MODE__ ]]; then
      printf '%s\t%s\t%s\n' "$path" "$kind" "$value" >> "$tmp_manifest"
      continue
    fi
    if ! safe_parent "$path"; then
      printf '%s\t%s\t%s\n' "$path" "$kind" "$value" >> "$tmp_manifest"
      continue
    fi
    current=''
    if [[ $kind == link && -L $path ]]; then
      current="$(readlink "$path")"
    elif [[ $kind == file && -f $path && ! -L $path ]]; then
      if ! current="$(hash_path "$path")"; then
        echo "Preserved unhashable entry: $path" >&2
        printf '%s\t%s\t%s\n' "$path" "$kind" "$value" >> "$tmp_manifest"
        continue
      fi
    elif [[ $kind == tree && -d $path && ! -L $path ]]; then
      if ! current="$(hash_path "$path")"; then
        echo "Preserved unhashable entry: $path" >&2
        printf '%s\t%s\t%s\n' "$path" "$kind" "$value" >> "$tmp_manifest"
        continue
      fi
    fi
    if [[ $kind == link && -L $path && $current == "$value" ]] || [[ $kind == file && -f $path && ! -L $path && $current == "$value" ]] || [[ $kind == tree && -d $path && ! -L $path && $current == "$value" ]]; then
      if [[ -d $path && ! -L $path ]]; then
        rm -r "$path"
      else
        rm "$path"
      fi
      echo "Removed: $path"
    elif [[ -e $path || -L $path ]]; then
      echo "Preserved modified file: $path" >&2
      printf '%s\t%s\t%s\n' "$path" "$kind" "$value" >> "$tmp_manifest"
    fi
  done < "$manifest"
  if grep -qv '^__MODE__' "$tmp_manifest"; then
    mv "$tmp_manifest" "$manifest"
  else
    rm -f "$manifest" "$tmp_manifest"
  fi
  echo "Sage uninstall complete."
  exit 0
fi

# Build the complete destination list and verify ownership before any writes.
declare -a srcs dests kinds
for skill in "$repo_dir"/skills/*; do
  if [[ ! -d $skill ]]; then
    continue
  fi
  srcs+=("$skill")
  dests+=("$codex_dir/skills/$(basename "$skill")")
  kinds+=(skill)
done
srcs+=("$repo_dir/model-instructions/sage.md")
dests+=("$codex_dir/model-instructions/sage.md")
kinds+=(model)
for agent in "$repo_dir"/agents/*.toml; do
  if [[ ! -f $agent ]]; then
    continue
  fi
  srcs+=("$agent")
  dests+=("$codex_dir/agents/$(basename "$agent")")
  kinds+=(agent)
done
mkdir -p "$manifest_dir"
declare -A owned_kind owned_value
if [[ -f $manifest ]]; then
  while IFS=$'\t' read -r p k v; do
    [[ $p && $p != '#'* ]] || continue
    if ! valid_manifest_entry "$p" "$k" "$v"; then
      echo "Invalid manifest entry: $p" >&2
      exit 1
    fi
    owned_kind["$p"]="$k"
    owned_value["$p"]="$v"
  done < "$manifest"
fi
old_mode="${owned_value[__MODE__]:-}"
if [[ -n $old_mode && $old_mode != "$mode" ]]; then
  echo "Mode switching is unsupported (existing: $old_mode, requested: $mode). Uninstall first." >&2
  exit 1
fi
for i in "${!dests[@]}"; do
  d=${dests[i]}
  k=${kinds[i]}
  safe_parent "$d"
  if [[ -v "owned_kind[$d]" ]]; then
    if [[ ${owned_kind[$d]} != file && ${owned_kind[$d]} != tree && ${owned_kind[$d]} != link ]]; then
      echo "Invalid manifest entry: $d" >&2
      exit 1
    fi
    if [[ ${owned_kind[$d]} == file && -f $d && ! -L $d ]]; then
      cur=$(hash_path "$d")
      if [[ $cur != "${owned_value[$d]}" ]]; then
        echo "Refusing modified owned file: $d" >&2
        exit 1
      fi
    elif [[ ${owned_kind[$d]} == tree && -d $d && ! -L $d ]]; then
      cur=$(hash_path "$d")
      if [[ $cur != "${owned_value[$d]}" ]]; then
        echo "Refusing modified owned tree: $d" >&2
        exit 1
      fi
    elif [[ ${owned_kind[$d]} == link && -L $d ]]; then
      if [[ $(readlink "$d") != "${owned_value[$d]}" ]]; then
        echo "Refusing modified owned link: $d" >&2
        exit 1
      fi
    else
      echo "Refusing changed owned destination: $d" >&2
      exit 1
    fi
  elif [[ -e $d || -L $d ]]; then
    echo "Cannot install: this path already exists and is not recorded as installed by Sage:" >&2
    echo "  $d" >&2
    echo "Back it up or move it, then rerun installation." >&2
    exit 1
  fi
done
if [[ $activate == true ]]; then
  config_safe || exit 1
  config_state >/dev/null || exit 1
fi
mkdir -p "$codex_dir/skills" "$codex_dir/model-instructions" "$codex_dir/agents"
if [[ ! -v "owned_kind[__MODE__]" ]]; then
  record __MODE__ mode "$mode"
fi
for i in "${!dests[@]}"; do
  s=${srcs[i]}
  d=${dests[i]}
  k=${kinds[i]}
  if [[ $mode == dev && $k != agent ]]; then
    if [[ -e $d || -L $d ]]; then
      rm -f "$d"
    fi
    ln -s "$s" "$d"
    record "$d" link "$s"
    echo "Linked: $d"
  else
    if [[ -d $d && $k == skill ]]; then
      rm -rf "$d"
    fi
    if [[ $k == skill ]]; then
      cp -R "$s" "$d"
    else
      cp "$s" "$d"
    fi
    if [[ $k == skill ]]; then
      digest=$(hash_path "$d") || exit 1
      record "$d" tree "$digest"
    else
      digest=$(hash_path "$d") || exit 1
      record "$d" file "$digest"
    fi
    echo "Copied: $d"
  fi
done
if [[ $activate == true ]]; then
  if [[ ! -v "owned_kind[__ACTIVATION__]" ]]; then
    saved_state=$(config_state) || exit 1
    if [[ $saved_state == absent ]]; then
      record __ACTIVATION__ state absent
    else
      saved_line=${saved_state#present:}
      record __ACTIVATION__ state "present:$(printf '%s' "$saved_line" | base64 -w0)"
    fi
  fi
  config_rewrite activate || exit 1
fi
if [[ $activate == true ]]; then
  echo "Activated Sage model instructions."
else
  echo "Sage model instructions not activated."
fi

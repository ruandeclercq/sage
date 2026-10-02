#!/usr/bin/env bash
set -Eeuo pipefail
case_name=initial
trap 'printf "test case %s failed at line %s: %s\n" "$case_name" "$LINENO" "$BASH_COMMAND" >&2' ERR
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
mkdir -p "$repo/skills/one" "$repo/skills/two" "$repo/model-instructions" "$repo/agents"
cp "$(dirname "$0")/setup.sh" "$repo/setup.sh"
chmod +x "$repo/setup.sh"
printf one > "$repo/skills/one/SKILL.md"
printf two > "$repo/skills/two/SKILL.md"
printf model > "$repo/model-instructions/sage.md"
printf agent > "$repo/agents/example.toml"
run() {
  HOME="$home" "$repo/setup.sh" "$@"
}
home="$repo/home"

# Basic copy, update, argument, and uninstall behavior.
mkdir -p "$home/.codex"
printf 'unchanged = true\n' > "$home/.codex/config.toml"
run install >/dev/null
[[ -f $home/.codex/skills/one/SKILL.md ]]
run install >/dev/null
[[ ! -e $home/.codex/skills/one/one ]]
printf changed > "$repo/skills/one/SKILL.md"
run install >/dev/null
[[ $(cat "$home/.codex/skills/one/SKILL.md") == changed ]]
if run nope >/dev/null 2>&1; then exit 1; fi
if run install --bad >/dev/null 2>&1; then exit 1; fi
if run install --dev >/dev/null 2>&1; then exit 1; fi
run uninstall >/dev/null
run uninstall >/dev/null
[[ ! -e $home/.codex/skills/one ]]
[[ $(cat "$home/.codex/config.toml") == 'unchanged = true' ]]
run install --dev >/dev/null
[[ -L $home/.codex/skills/one ]]
run uninstall >/dev/null
run install >/dev/null
printf user > "$home/.codex/agents/example.toml"
if run install >/dev/null 2>&1; then exit 1; fi
rm "$home/.codex/agents/example.toml"
rm "$home/.codex/model-instructions/sage.md"
ln -s "$repo/model-instructions/sage.md" "$home/.codex/model-instructions/sage.md"
if run install >/dev/null 2>&1; then exit 1; fi
rm "$home/.codex/model-instructions/sage.md"
run uninstall >/dev/null
rm -rf "$home/.codex/skills/one" "$home/.codex/model-instructions/sage.md" "$home/.codex/agents/example.toml"
rm -f "$home/.codex/sage/manifest"
run install >/dev/null
rm "$home/.codex/skills/one/SKILL.md"
ln -s "$repo/skills/one/SKILL.md" "$home/.codex/skills/one/SKILL.md"
if run install >/dev/null 2>&1; then exit 1; fi
ln -s "$repo" "$repo/unsafe"
if HOME="$repo/unsafe" "$repo/setup.sh" install >/dev/null 2>&1; then exit 1; fi
rm "$repo/unsafe"
rm -rf "$home/.codex/sage"
ln -s "$repo/nowhere" "$home/.codex/sage"
if run uninstall >/dev/null 2>&1; then exit 1; fi
rm "$home/.codex/sage"
rm -rf "$home/.codex"
mkdir -p "$home/.codex" "$repo/bin"
cat > "$repo/bin/cp" <<'WRAP'
#!/usr/bin/env bash
for arg in "$@"; do [[ $arg == *example.toml ]] && exit 77; done
exec /bin/cp "$@"
WRAP
chmod +x "$repo/bin/cp"
if PATH="$repo/bin:$PATH" run install >/dev/null 2>&1; then exit 1; fi
[[ -f $home/.codex/skills/one/SKILL.md ]]
[[ -f $home/.codex/sage/manifest ]]
run uninstall >/dev/null
[[ ! -e $home/.codex/skills/one ]]

# Destination safety and recovery after failed writes.
newhome() {
  case_name=$1
  home="$repo/$1"
  rm -rf "$home"
  mkdir -p "$home/.codex/agents"
}

newhome devrepeat
run install --dev >/dev/null
run install --dev >/dev/null
printf updated-agent > "$repo/agents/example.toml"
run install --dev >/dev/null
[[ $(cat "$home/.codex/agents/example.toml") == updated-agent ]]
[[ $(readlink "$home/.codex/skills/one") == "$repo/skills/one" ]]

newhome collision
printf occupied > "$home/.codex/agents/example.toml"
if run install >/dev/null 2>"$home/collision.err"; then exit 1; fi
grep -Fx "Cannot install: this path already exists and is not recorded as installed by Sage:" "$home/collision.err"
grep -Fx "  $home/.codex/agents/example.toml" "$home/collision.err"
grep -Fx "Back it up or move it, then rerun installation." "$home/collision.err"
[[ ! -e "$home/.codex/skills/one" ]]
[[ ! -e "$home/.codex/model-instructions/sage.md" ]]

# Preservation of user-owned and changed paths.
newhome emptydir
run install >/dev/null
mkdir "$home/.codex/skills/one/user-empty"
if run install >/dev/null 2>&1; then exit 1; fi
run uninstall >/dev/null
[[ -d "$home/.codex/skills/one/user-empty" ]]

newhome userlink
run install >/dev/null
ln -s /tmp "$home/.codex/skills/one/user-link"
if run install >/dev/null 2>&1; then exit 1; fi
run uninstall >/dev/null
[[ -L "$home/.codex/skills/one/user-link" ]]

newhome devmodified
run install --dev >/dev/null
rm "$home/.codex/skills/one"
ln -s /tmp "$home/.codex/skills/one"
if run install --dev >/dev/null 2>&1; then exit 1; fi
run uninstall >/dev/null
[[ $(readlink "$home/.codex/skills/one") == /tmp ]]
grep -F "$home/.codex/skills/one" "$home/.codex/sage/manifest"

newhome moved
run install >/dev/null
mv "$home/.codex/skills" "$home/skills-outside"
ln -s "$home/skills-outside" "$home/.codex/skills"
run uninstall >/dev/null 2>&1 || true
[[ -e "$home/skills-outside/one" ]]
grep -F "$home/.codex/skills/one" "$home/.codex/sage/manifest"

newhome codexlink
rm -rf "$home/.codex"
mkdir -p "$home/outside"
ln -s "$home/outside" "$home/.codex"
if run install >/dev/null 2>&1; then exit 1; fi
[[ ! -e "$home/outside/sage" ]]

newhome manifestlink
run install >/dev/null
cp "$home/.codex/sage/manifest" "$home/saved-manifest"
rm "$home/.codex/sage/manifest"
ln -s "$home/saved-manifest" "$home/.codex/sage/manifest"
if run install >/dev/null 2>&1; then exit 1; fi
if run uninstall >/dev/null 2>&1; then exit 1; fi
cmp "$home/saved-manifest" "$home/.codex/sage/manifest"

newhome fifo
run install >/dev/null
mkfifo "$home/.codex/skills/one/user-fifo"
if timeout 5 bash -c 'HOME="$1" "$2" uninstall >/dev/null 2>&1' _ "$home" "$repo/setup.sh"; then :; else exit 1; fi
[[ -p "$home/.codex/skills/one/user-fifo" ]]
[[ ! -e "$home/.codex/skills/two" ]]
grep -F "$home/.codex/skills/one" "$home/.codex/sage/manifest"

newhome outscope
run install >/dev/null
printf keep > "$home/unrelated-file"
hash=$(sha256sum "$home/unrelated-file" | awk '{print $1}')
printf '%s\tfile\t%s\n' "$home/unrelated-file" "$hash" >> "$home/.codex/sage/manifest"
if run uninstall >/dev/null 2>&1; then exit 1; fi
[[ -f "$home/unrelated-file" ]]
[[ -f "$home/.codex/skills/one/SKILL.md" ]]
[[ -f "$home/.codex/skills/two/SKILL.md" ]]
[[ -f "$home/.codex/model-instructions/sage.md" ]]
[[ -f "$home/.codex/agents/example.toml" ]]

newhome traversal
run install >/dev/null
printf '%s\tfile\t%s\n' "$home/.codex/skills/../escape" "$hash" >> "$home/.codex/sage/manifest"
if run uninstall >/dev/null 2>&1; then exit 1; fi
[[ -f "$home/.codex/skills/one/SKILL.md" ]]
[[ -f "$home/.codex/skills/two/SKILL.md" ]]
[[ -f "$home/.codex/model-instructions/sage.md" ]]
[[ -f "$home/.codex/agents/example.toml" ]]

# Activation acceptance and restoration.
newhome act_absent
run install --activate >/dev/null
grep -Fx 'model_instructions_file = "~/.codex/model-instructions/sage.md"' "$home/.codex/config.toml"
grep -F $'__ACTIVATION__\tstate\tabsent' "$home/.codex/sage/manifest"
run uninstall >/dev/null
[[ ! -e "$home/.codex/sage/manifest" ]]
[[ ! -s "$home/.codex/config.toml" ]]

newhome act_existing
printf 'keep = "a\\b"\nmodel_instructions_file = "old.md" # keep\n[profiles.x]\nname = "x"\n' > "$home/.codex/config.toml"
original=$(cat "$home/.codex/config.toml")
run install --activate >/dev/null
run install --activate >/dev/null
run uninstall >/dev/null
[[ $(cat "$home/.codex/config.toml") == "$original" ]]

newhome act_profiles
printf '[profiles.x]\nmodel_instructions_file = "profile.md"\n' > "$home/.codex/config.toml"
run install --activate >/dev/null
grep -q 'model_instructions_file = "~/.codex/model-instructions/sage.md"' "$home/.codex/config.toml"
run uninstall >/dev/null
grep -q 'model_instructions_file = "profile.md"' "$home/.codex/config.toml"

newhome act_orders
run install --activate --dev >/dev/null
run uninstall >/dev/null
run install --dev --activate >/dev/null

newhome act_edits
printf 'before = true\n[profiles.x]\nvalue = 1\n' > "$home/.codex/config.toml"
run install --activate >/dev/null
printf 'before = false\nmodel_instructions_file = "~/.codex/model-instructions/sage.md"\n[profiles.x]\nvalue = 2\n' > "$home/.codex/config.toml"
run uninstall >/dev/null
grep -q 'value = 2' "$home/.codex/config.toml"

newhome act_userpath
run install --activate >/dev/null
sed -i 's#model-instructions/sage.md#other.md#' "$home/.codex/config.toml"
run uninstall >/dev/null
grep -q other.md "$home/.codex/config.toml"

newhome act_format
printf 'model_instructions_file = "old.md"\n' > "$home/.codex/config.toml"
run install --activate >/dev/null
printf "  model_instructions_file = '~/.codex/model-instructions/sage.md' # user\n" > "$home/.codex/config.toml"
run uninstall >/dev/null
grep -Fx 'model_instructions_file = "old.md"' "$home/.codex/config.toml"

for bad in \
  'model_instructions_file = "one"\nmodel_instructions_file = "two"' \
  'config.model_instructions_file = "x"' \
  'model_instructions_file = """x"""' \
  'model_instructions_file = "unterminated' \
  'items = [1,\n2]' \
  'text = "unterminated' \
  '"model_instructions_file" = "x"' \
  'model_instructions_file = 42'; do
  newhome "act_layout_$RANDOM"
  printf '%b\n' "$bad" > "$home/.codex/config.toml"
  before=$(sha256sum "$home/.codex/config.toml" | awk '{print $1}')
  if run install --activate >/dev/null 2>&1; then exit 1; fi
  [[ $(sha256sum "$home/.codex/config.toml" | awk '{print $1}') == "$before" ]]
  [[ ! -e "$home/.codex/model-instructions/sage.md" ]]
  [[ -z $(find "$home/.codex" -maxdepth 1 -name '.config.toml.*' -o -name '.saved.*') ]]
done

newhome act_exact
printf "model_instructions_file\t=\t'old\\path' # comment\n" > "$home/.codex/config.toml"
expected=$(cat "$home/.codex/config.toml")
run install --activate >/dev/null
run uninstall >/dev/null
[[ $(cat "$home/.codex/config.toml") == "$expected" ]]

newhome act_unsafe
ln -s "$repo/no-config" "$home/.codex/config.toml"
if run install --activate >/dev/null 2>&1; then exit 1; fi
rm "$home/.codex/config.toml"
mkdir "$home/.codex/config.toml"
if run install --activate >/dev/null 2>&1; then exit 1; fi

newhome act_copyfail
printf 'unchanged = true\n' > "$home/.codex/config.toml"
if PATH="$repo/bin:$PATH" run install --activate >/dev/null 2>&1; then exit 1; fi
[[ $(cat "$home/.codex/config.toml") == 'unchanged = true' ]]

newhome act_retry
printf 'model_instructions_file = "old.md"\n' > "$home/.codex/config.toml"
run install --activate >/dev/null
rm "$home/.codex/config.toml"
mkdir "$home/.codex/config.toml"
if run uninstall >/dev/null 2>&1; then exit 1; fi
[[ -f "$home/.codex/sage/manifest" && -f "$home/.codex/model-instructions/sage.md" ]]
rm -rf "$home/.codex/config.toml"
printf 'model_instructions_file = "~/.codex/model-instructions/sage.md"\n' > "$home/.codex/config.toml"
run uninstall >/dev/null
grep -Fx 'model_instructions_file = "old.md"' "$home/.codex/config.toml"
[[ ! -e "$home/.codex/model-instructions/sage.md" && ! -e "$home/.codex/sage/manifest" ]]

newhome act_line_endings
printf 'model_instructions_file = "old.md"\r\n' > "$home/.codex/config.toml"
cp "$home/.codex/config.toml" "$home/crlf.orig"
chmod 640 "$home/.codex/config.toml"
run install --activate >/dev/null
run uninstall >/dev/null
cmp "$home/crlf.orig" "$home/.codex/config.toml"
[[ $(stat -c %a "$home/.codex/config.toml") == 640 ]]
printf 'model_instructions_file = "old.md"' > "$home/.codex/config.toml"
cp "$home/.codex/config.toml" "$home/nonl.orig"
run install --activate >/dev/null
run uninstall >/dev/null
cmp "$home/nonl.orig" "$home/.codex/config.toml"

newhome act_pyfail
printf 'model_instructions_file = "old.md"\n' > "$home/.codex/config.toml"
run install --activate >/dev/null
cp "$home/.codex/config.toml" "$home/config.saved"
cp "$home/.codex/sage/manifest" "$home/manifest.saved"
mkdir "$repo/pyfail"
cat > "$repo/pyfail/python3" <<'WRAP'
#!/usr/bin/env bash
[[ ${2:-} == restore ]] && exit 77
exec /usr/bin/python3 "$@"
WRAP
chmod +x "$repo/pyfail/python3"
if PATH="$repo/pyfail:$PATH" run uninstall >/dev/null 2>&1; then exit 1; fi
cmp "$home/config.saved" "$home/.codex/config.toml"
cmp "$home/manifest.saved" "$home/.codex/sage/manifest"
[[ -f "$home/.codex/model-instructions/sage.md" ]]
run uninstall >/dev/null
grep -Fx 'model_instructions_file = "old.md"' "$home/.codex/config.toml"

newhome act_corrupt_state
run install --activate >/dev/null
sed -i 's/state\t[^\t]*/state\t%%%/' "$home/.codex/sage/manifest"
if run uninstall >/dev/null 2>&1; then exit 1; fi
[[ -f "$home/.codex/model-instructions/sage.md" && -f "$home/.codex/sage/manifest" ]]

# Corrupt saved activation state must preserve the installation for retry.
for corrupt in '%%%' 'd3Jvbmdfa2V5ID0gIngi' 'bW9kZWxfaW5zdHJ1Y3Rpb25zX2ZpbGUgPSAiYmFkXHFyIg=='; do
  newhome "act_saved_$RANDOM"
  run install --activate >/dev/null
  sed -i "s#^__ACTIVATION__.*#__ACTIVATION__\tstate\tpresent:$corrupt#" "$home/.codex/sage/manifest"
  cp "$home/.codex/config.toml" "$home/config.saved"
  cp "$home/.codex/sage/manifest" "$home/manifest.saved"
  if run uninstall >/dev/null 2>&1; then exit 1; fi
  cmp "$home/config.saved" "$home/.codex/config.toml"
  cmp "$home/manifest.saved" "$home/.codex/sage/manifest"
  [[ -f "$home/.codex/model-instructions/sage.md" ]]
done

echo 'setup acceptance tests passed'

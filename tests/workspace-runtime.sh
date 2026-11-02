#!/usr/bin/env bash
# Run inside the image with the normal entrypoint bypassed.
set -euo pipefail
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/repo" "$fixture/home/.ssh" "$fixture/tools"
export APP_ROOT="$fixture/repo" HOME="$fixture/home"
printf 'Host saved\n' > "$HOME/.ssh/config"
printf '[user]\n  name = Developer\n' > "$HOME/.gitconfig"
cp "$HOME/.ssh/config" "$fixture/ssh.expected"
cp "$HOME/.gitconfig" "$fixture/git.expected"
# Configuration succeeds repeatedly without running storage/init or identity setup.
/docker-entrypoint.sh --configure-runtime
/docker-entrypoint.sh --configure-runtime
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
bash -lc 'command -v cargo' >/dev/null
cd "$APP_ROOT"
git init -q
printf 'tracked\n' > source.txt
git add source.txt
workspace-path > "$fixture/path"
test "$(cat "$fixture/path")" = "$APP_ROOT/.wodby-workspace"
test -z "$(git ls-files --others --exclude-standard)"
# A tracked collision is refused, even when local exclude rules hide new files.
printf collision > .wodby-workspace/collision
git add -f .wodby-workspace/collision
if workspace-path; then echo 'accepted tracked runtime storage' >&2; exit 1; fi
git rm -q --cached .wodby-workspace/collision
rm .wodby-workspace/collision
export PATH="$fixture/tools:$PATH"
if workspace-rust prepare 2>/dev/null; then echo 'prepared without Cargo.toml' >&2; exit 1; fi
# A real build proves the lock file is kept and startup recompiles.
mkdir src
printf '[package]\nname = "workspace"\nversion = "0.1.0"\nedition = "2024"\n\n[dependencies]\n' > Cargo.toml
printf 'fn main() { print!("before"); }\n' > src/main.rs
cp Cargo.toml "$fixture/manifest.expected"
workspace-rust prepare
# Without a lock file, Cargo creates one, as on any first build; it is used as is from then on.
test -f Cargo.lock
cp Cargo.lock "$fixture/lock.expected"
test "$(workspace-rust start)" = before
# Compiled artifacts and Cargo's registry are kept with the checkout, not in
# the container's home, which a restart discards; a custom start command gets
# the same settings.
state="$APP_ROOT/.wodby-workspace"
test -x "$state/target/debug/workspace"
test "$(WORKSPACE_RUST_COMMAND='printf "%s %s %s %s" "$CARGO_HOME" "$CARGO_TARGET_DIR" "$HOST" "$PORT"' workspace-rust start)" = "$state/cargo $state/target 0.0.0.0 8080"
test -z "$(git ls-files --others --exclude-standard -- .wodby-workspace)"
# Settings changed from the image's defaults stay as set.
test "$(CARGO_HOME="$fixture/cargo" CARGO_TARGET_DIR="$fixture/target" WORKSPACE_RUST_COMMAND='printf "%s %s" "$CARGO_HOME" "$CARGO_TARGET_DIR"' workspace-rust start)" = "$fixture/cargo $fixture/target"
# Several binaries need a selection, or the package's default-run binary.
mkdir src/bin
printf 'fn main() { print!("tool"); }\n' > src/bin/tool.rs
if workspace-rust start 2>/dev/null; then echo 'started one of several binaries' >&2; exit 1; fi
test "$(WORKSPACE_RUST_BIN=tool workspace-rust start)" = tool
sed -i 's/^edition = "2024"$/edition = "2024"\ndefault-run = "workspace"/' Cargo.toml
test "$(workspace-rust start)" = before
cp "$fixture/manifest.expected" Cargo.toml
rm -r src/bin
# An outdated lock file fails the build instead of being rewritten.
printf 'fn main() { print!("after"); }\n' > src/main.rs
test "$(WODBY_WORKSPACE=1 /docker-entrypoint.sh ignored)" = after
cmp Cargo.lock "$fixture/lock.expected"
printf '[package]\nname = "renamed"\nversion = "0.1.0"\nedition = "2024"\n\n[dependencies]\n' > Cargo.toml
if workspace-rust start 2>/dev/null; then echo 'rewrote an outdated lock file' >&2; exit 1; fi
cmp Cargo.lock "$fixture/lock.expected"
cmp "$HOME/.ssh/config" "$fixture/ssh.expected"
cmp "$HOME/.gitconfig" "$fixture/git.expected"
echo 'Workspace runtime checks passed'

#!/usr/bin/env bash
# A change another container writes to the shared checkout is compiled and served without
# restarting the container, a build that fails leaves the running build up, and the watcher
# stops with its application. This does not substitute for cross-node NFS acceptance.
set -euo pipefail
volume="workspace-rust-reload-$$"
server="workspace-rust-reload-server-$$"
docker volume create "$volume" >/dev/null
cleanup() { docker rm -f "$server" >/dev/null 2>&1 || true; docker volume rm "$volume" >/dev/null; }
trap cleanup EXIT
image="${IMAGE:?Set IMAGE to the candidate Rust development image}"
# Run as the image's own user: the checkout belongs to it in a workspace.
write() { docker run --rm -i --network none --entrypoint sh -v "$volume:/fixture" "$image" -ec "$1"; }
docker run --rm --user 0 --entrypoint sh -v "$volume:/fixture" "$image" -ec 'chown "$(id -u wodby):$(id -g wodby)" /fixture'
write '
cd /fixture
git init -q
mkdir src
printf "[package]\nname = \"reload\"\nversion = \"0.1.0\"\nedition = \"2024\"\n\n[dependencies]\n" > Cargo.toml
printf "embedded-before" > static.txt
cat > src/main.rs <<RS
use std::io::{Read, Write};
use std::net::TcpListener;

const STATIC: &str = include_str!("../static.txt");

fn main() {
    let port = std::env::var("PORT").unwrap();
    let listener = TcpListener::bind(format!("0.0.0.0:{port}")).unwrap();
    for stream in listener.incoming() {
        let mut stream = stream.unwrap();
        let mut request = [0; 1024];
        let size = stream.read(&mut request).unwrap();
        let request = String::from_utf8_lossy(&request[..size]);
        let path = request.split_whitespace().nth(1).unwrap_or("/");
        let body = match path {
            "/static" => STATIC,
            "/exit" => std::process::exit(7),
            _ => "before-edit",
        };
        write!(stream, "HTTP/1.0 200 OK\\r\\nContent-Length: {}\\r\\n\\r\\n{}", body.len(), body).unwrap();
    }
}
RS
'
start() { docker run -d --name "$server" --network none --entrypoint /usr/local/bin/workspace-rust -e APP_ROOT=/fixture -e WORKSPACE_POLL_INTERVAL=500 "$@" -v "$volume:/fixture" "$image" start >/dev/null; }
get() { docker exec "$server" wget -qO- "http://127.0.0.1:8080$1" 2>/dev/null; }
# Waits until a path answers with the wanted text; prints the server's log when it never does.
serves() {
 for _ in $(seq 1 90); do
  if [ "$(get "$1" || true)" = "$2" ]; then return 0; fi
  sleep 1
 done
 echo "$1 never answered $2" >&2; docker logs "$server" >&2; exit 1
}
start
serves / before-edit
serves /static embedded-before
first=$(docker inspect -f '{{.State.StartedAt}}' "$server")

write 'sed -i "s/before-edit/after-edit/" /fixture/src/main.rs'
serves / after-edit
echo 'rust: a change to the source was compiled and served'

# A build that fails must not take the running build down.
write 'printf "\nfn broken( {\n" >> /fixture/src/main.rs'
for _ in $(seq 1 60); do
 if docker logs "$server" 2>&1 | grep -q 'the build failed; the previous build keeps running'; then break; fi
 sleep 1
done
docker logs "$server" 2>&1 | grep -q 'the build failed; the previous build keeps running'
serves / after-edit
echo 'rust: a failed build left the running build up'

# Fixed again, with a change to a file the build embeds.
write 'sed -i "/^fn broken( {$/d" /fixture/src/main.rs; printf "embedded-after" > /fixture/static.txt'
serves /static embedded-after
echo 'rust: a change to an embedded file was compiled and served'

# All of that happened in one container.
test "$(docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' "$server")" = "$first 0"

# Storage for builds and caches is not watched: nothing is compiled while nothing changes.
builds=$(docker logs "$server" 2>&1 | grep -c 'the checkout changed; compiling')
sleep 5
test "$(docker logs "$server" 2>&1 | grep -c 'the checkout changed; compiling')" = "$builds"

# Stopping the container stops the application at once, without waiting for the kill timeout.
began=$(date +%s)
docker stop -t 30 "$server" >/dev/null
test $(( $(date +%s) - began )) -lt 10
test "$(docker inspect -f '{{.State.ExitCode}}' "$server")" = 143
docker rm -f "$server" >/dev/null
echo 'rust: stopping the container stopped the application'

# An application that ends by itself ends the container with its exit code.
start
serves / after-edit
get /exit || true
for _ in $(seq 1 20); do
 [ "$(docker inspect -f '{{.State.Running}}' "$server")" = false ] && break
 sleep 1
done
test "$(docker inspect -f '{{.State.Running}} {{.State.ExitCode}}' "$server")" = 'false 7'
docker rm -f "$server" >/dev/null
echo 'rust: an application that ended took the container with it'

# Without watching the application replaces the script, as before.
start -e WORKSPACE_RUST_WATCH=0
serves / after-edit
test "$(docker exec "$server" sh -c 'tr "\0" " " < /proc/1/cmdline')" = '/fixture/.wodby-workspace/target/debug/reload '
write 'sed -i "s/after-edit/unwatched/" /fixture/src/main.rs'
sleep 5
test "$(get /)" = after-edit
echo 'rust: WORKSPACE_RUST_WATCH=0 runs the application without a watcher'

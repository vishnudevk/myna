#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TMP="$(mktemp -d)"
DAEMON_PID=""
APP_PID=""

cleanup() {
    if [[ -n "$DAEMON_PID" ]] && kill -0 "$DAEMON_PID" 2>/dev/null; then
        kill "$DAEMON_PID" 2>/dev/null || true
        wait "$DAEMON_PID" 2>/dev/null || true
    fi
    if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
        wait "$APP_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$TMP/bin" "$TMP/run/myna/whisper"

# Leave behind a Unix socket with no listener, as happens when GNOME kills a
# background Flatpak instance whose backend has already exited.
python3 - "$TMP/run/myna/whisper/myna.sock" <<'PY'
import socket
import sys

server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(sys.argv[1])
PY

cat >"$TMP/bin/gdbus" <<'EOF'
#!/bin/sh
echo '(false,)'
EOF

cat >"$TMP/bin/myna-daemon" <<EOF
#!/bin/sh
echo \$\$ >"$TMP/daemon.pid"
exec sleep 60
EOF

cat >"$TMP/bin/myna-config" <<EOF
#!/bin/sh
echo \$\$ >"$TMP/config.pid"
EOF

chmod +x "$TMP/bin/gdbus" "$TMP/bin/myna-daemon" "$TMP/bin/myna-config"

PATH="$TMP/bin:$PATH" \
MYNA_APP_BIN_DIR="$TMP/bin" \
XDG_RUNTIME_DIR="$TMP/run" \
    "$PROJECT_ROOT/scripts/myna-app" &
APP_PID=$!

for _ in {1..50}; do
    if [[ -f "$TMP/config.pid" && -f "$TMP/daemon.pid" ]]; then
        break
    fi
    sleep 0.1
done

test -f "$TMP/config.pid"
test -f "$TMP/daemon.pid"

DAEMON_PID="$(cat "$TMP/daemon.pid")"
CONFIG_PID="$(cat "$TMP/config.pid")"

kill -0 "$DAEMON_PID"
kill -0 "$APP_PID"
test ! -e "$TMP/run/myna/whisper/myna.sock"
if kill -0 "$CONFIG_PID" 2>/dev/null; then
    echo "myna-app lifecycle test failed: settings UI did not exit" >&2
    exit 1
fi

kill -TERM "$APP_PID"
wait "$APP_PID" || true
if kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "myna-app lifecycle test failed: launcher termination left the daemon running" >&2
    exit 1
fi

# Reopening Settings while the background daemon already owns its D-Bus name
# must not spawn a second daemon.
cat >"$TMP/bin/gdbus" <<'EOF'
#!/bin/sh
echo '(true,)'
EOF
rm -f "$TMP/daemon.pid" "$TMP/config.pid"

PATH="$TMP/bin:$PATH" \
MYNA_APP_BIN_DIR="$TMP/bin" \
XDG_RUNTIME_DIR="$TMP/run" \
    "$PROJECT_ROOT/scripts/myna-app"

test -f "$TMP/config.pid"
if [[ -f "$TMP/daemon.pid" ]]; then
    echo "myna-app lifecycle test failed: reopening Settings spawned a second daemon" >&2
    exit 1
fi

echo "myna-app lifecycle test passed: Settings close keeps Myna alive; launcher stop cleans it up"

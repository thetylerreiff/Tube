#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Tube"
BUNDLE_ID="com.tylerreiff.tube"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/Build/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

stop_running_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  echo "error: $APP_NAME did not quit" >&2
  return 1
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

wait_for_app() {
  for _ in {1..20}; do
    if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done

  echo "error: $APP_NAME did not launch" >&2
  return 1
}

stop_running_app
"$ROOT_DIR/scripts/build-app.sh" debug >/dev/null

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    open_app
    wait_for_app
    lldb -p "$(pgrep -n -x "$APP_NAME")"
    ;;
  --logs|logs)
    open_app
    wait_for_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    wait_for_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    wait_for_app
    echo "$APP_NAME is running from $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

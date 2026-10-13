#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$SCRIPT_DIR/OrdersProof.csproj"
RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stefanini-orders-proof.XXXXXX")"
DB_PATH="$RUN_DIR/orders.db"
LOG_PATH="$RUN_DIR/api.log"
RESPONSE_PATH="$RUN_DIR/response.json"
HEADERS_PATH="$RUN_DIR/headers.txt"
PORT="${ORDERS_PROOF_PORT:-}"
APP_PID=""

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  local_tmp_root="${TMPDIR:-/tmp}"
  local_tmp_root="${local_tmp_root%/}"
  case "$RUN_DIR" in
    "$local_tmp_root"/stefanini-orders-proof.*)
      rm -rf -- "$RUN_DIR"
      ;;
    *)
      printf 'Refusing to remove unexpected temporary path: %s\n' "$RUN_DIR" >&2
      ;;
  esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  if [[ -f "$LOG_PATH" ]]; then
    printf '\n--- API log ---\n' >&2
    cat "$LOG_PATH" >&2
  fi
  exit 1
}

assert_status() {
  local actual="$1" expected="$2" description="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$description (expected HTTP $expected, received $actual; body: $(cat "$RESPONSE_PATH" 2>/dev/null || true))"
  fi
  printf 'PASS  %s\n' "$description"
}

request() {
  local method="$1" path="$2" key="$3" body="$4"
  local -a args=(--silent --show-error --output "$RESPONSE_PATH" --dump-header "$HEADERS_PATH" --write-out '%{http_code}' --request "$method")
  if [[ -n "$key" ]]; then
    args+=(--header "Idempotency-Key: $key")
  fi
  args+=(--header 'X-Demo-Tenant: synthetic-tenant')
  if [[ -n "$body" ]]; then
    args+=(--header 'Content-Type: application/json' --data-binary "$body")
  fi
  curl "${args[@]}" "http://127.0.0.1:$PORT$path"
}

json_value() {
  python3 -c 'import json,sys; data=json.load(open(sys.argv[1],encoding="utf-8")); print(data[sys.argv[2]])' "$RESPONSE_PATH" "$1"
}

if ! command -v dotnet >/dev/null 2>&1; then
  fail 'The .NET SDK is required (10.x recommended).'
fi
if ! command -v curl >/dev/null 2>&1; then
  fail 'curl is required to send the proof requests.'
fi
if ! command -v python3 >/dev/null 2>&1; then
  fail 'python3 is required to inspect JSON responses.'
fi

if [[ -z "$PORT" ]]; then
  PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
fi
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  fail 'ORDERS_PROOF_PORT must be an available TCP port from 1 to 65535.'
fi

printf 'Building the .NET proof...\n'
dotnet build "$PROJECT" --configuration Release

DLL_PATH="$SCRIPT_DIR/bin/Release/net10.0/OrdersProof.dll"
if [[ ! -f "$DLL_PATH" ]]; then
  fail "Build succeeded but the API assembly was not found: $DLL_PATH"
fi

printf 'Starting the local API on port %s...\n' "$PORT"
ORDERS_DB_PATH="$DB_PATH" dotnet "$DLL_PATH" --urls "http://127.0.0.1:$PORT" >"$LOG_PATH" 2>&1 &
APP_PID=$!

ready=false
for ((attempt = 0; attempt < 60; attempt++)); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    fail 'The API process exited before becoming ready.'
  fi
  if curl --silent --fail "http://127.0.0.1:$PORT/health" >/dev/null; then
    ready=true
    break
  fi
  sleep 0.5
done
[[ "$ready" == true ]] || fail 'The API did not become ready within 30 seconds.'
printf 'PASS  API starts and responds on the health endpoint\n'

BODY='{"items":[{"productId":"SKU-100","description":"Teclado sintético","quantity":2,"unitPrice":125.50,"currency":"BRL"}]}'
CREATED_STATUS="$(request POST /v1/orders demo-key-00000001 "$BODY")" || fail 'Could not send the create request.'
assert_status "$CREATED_STATUS" 201 'First request creates and persists the order'
ORDER_ID="$(json_value orderId)"

REPLAY_STATUS="$(request POST /v1/orders demo-key-00000001 "$BODY")" || fail 'Could not send the replay request.'
assert_status "$REPLAY_STATUS" 200 'Retry with same key and payload replays the original order'
REPLAY_ID="$(json_value orderId)"
[[ "$REPLAY_ID" == "$ORDER_ID" ]] || fail 'Replay returned a different orderId.'
if ! grep -Eiq '^Idempotent-Replay:[[:space:]]*true' "$HEADERS_PATH"; then
  fail 'Replay response did not include Idempotent-Replay: true.'
fi
printf 'PASS  Replay is explicitly identified in the response\n'

CHANGED_BODY='{"items":[{"productId":"SKU-100","description":"Teclado sintético","quantity":3,"unitPrice":125.50,"currency":"BRL"}]}'
CONFLICT_STATUS="$(request POST /v1/orders demo-key-00000001 "$CHANGED_BODY")" || fail 'Could not send the conflicting request.'
assert_status "$CONFLICT_STATUS" 409 'Reusing a key with a different payload returns conflict'

MISSING_KEY_STATUS="$(request POST /v1/orders '' "$BODY")" || fail 'Could not send the missing-key request.'
assert_status "$MISSING_KEY_STATUS" 400 'Creation without Idempotency-Key is rejected'

INVALID_BODY='{"items":[{"productId":"SKU-200","description":"Item inválido","quantity":0,"unitPrice":9.99,"currency":"BRL"}]}'
INVALID_STATUS="$(request POST /v1/orders demo-key-00000002 "$INVALID_BODY")" || fail 'Could not send the invalid-item request.'
assert_status "$INVALID_STATUS" 400 'Invalid quantity is rejected'

LEGACY_STATUS="$(request GET "/v1/orders/$ORDER_ID" '' '')" || fail 'Could not send the compatibility lookup.'
assert_status "$LEGACY_STATUS" 200 'Existing v1 lookup remains available to the reference consumer'
python3 - "$RESPONSE_PATH" "$ORDER_ID" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    order = json.load(stream)
assert order["orderId"] == sys.argv[2]
assert order["status"] == "Accepted"
assert order["items"][0]["unitPrice"] == 125.5
assert order["items"][0]["lineTotal"] == 251
PY
printf 'PASS  Legacy response preserves v1 fields and the accepted price snapshot\n'

printf '\nProof completed successfully.\n'
printf 'The database used synthetic data and was stored temporarily at %s\n' "$DB_PATH"
printf 'This local proof does not provision Azure resources or measure production-scale performance.\n'

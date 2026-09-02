#!/usr/bin/env bash
set -uo pipefail

prompt=${1-}
model=${2-}
screenshot=${4-}
runtime=${XDG_RUNTIME_DIR:-/tmp}
state="$runtime/orbit-opencode-server"
data="$state/data"
base_url="http://127.0.0.1:4097"
directory=$PWD
opencode=$(command -v opencode || true)
if [[ -z "$opencode" && -x "$HOME/.local/share/mise/installs/opencode/latest/opencode" ]]; then
  opencode="$HOME/.local/share/mise/installs/opencode/latest/opencode"
fi
session=""
request_pid=""

if [[ -z "$opencode" ]]; then
  printf 'Orbit could not find the opencode executable.\n' >&2
  exit 127
fi

mkdir -p "$data/opencode"
ln -sfn "$HOME/.local/share/opencode/auth.json" "$data/opencode/auth.json"

server_ready() {
  curl --silent --fail --max-time 1 "$base_url/global/health" >/dev/null
}

start_server() {
  (
    flock 9
    server_ready && exit 0

    if [[ -s "$state/server.pid" ]]; then
      old_pid=$(<"$state/server.pid")
      kill "$old_pid" 2>/dev/null || true
    fi

    nohup env \
      XDG_DATA_HOME="$data" \
      OPENCODE_CONFIG_CONTENT='{"permission":{"*":"allow"}}' \
      "$opencode" serve --hostname 127.0.0.1 --port 4097 \
      </dev/null >>"$state/server.log" 2>&1 9>&- &
    echo "$!" >"$state/server.pid"

    for ((attempt = 0; attempt < 150; attempt++)); do
      server_ready && exit 0
      sleep 0.1
    done
    exit 1
  ) 9>"$state/server.lock"
}

session_url() {
  local suffix=${1-}
  local encoded
  encoded=$(jq -rn --arg value "$directory" '$value | @uri')
  printf '%s/session/%s%s?directory=%s' "$base_url" "$session" "$suffix" "$encoded"
}

discard_session() {
  [[ -n "$session" ]] || return
  curl --silent --max-time 2 -X DELETE "$(session_url)" >/dev/null 2>&1 || true
  session=""
}

abort_request() {
  [[ -n "$request_pid" ]] && kill "$request_pid" 2>/dev/null || true
  if [[ -n "$session" ]]; then
    curl --silent --max-time 2 -X POST "$(session_url /abort)" >/dev/null 2>&1 || true
  fi
  discard_session
  exit 130
}
trap abort_request INT TERM
trap discard_session EXIT

if ! start_server; then
  [[ -s "$state/server.log" ]] && /usr/bin/cat "$state/server.log" >&2
  exit 1
fi

encoded_directory=$(jq -rn --arg value "$directory" '$value | @uri')
session=$(curl --silent --fail -X POST \
  -H 'Content-Type: application/json' \
  -d '{"title":"Orbit request"}' \
  "$base_url/session?directory=$encoded_directory" | jq -r '.id // empty')
if [[ -z "$session" ]]; then
  printf 'OpenCode did not create a session.\n' >&2
  exit 1
fi

body=$(jq -n --arg prompt "$prompt" --arg model "$model" --arg screenshot "$screenshot" '
  {
    parts: ([{type: "text", text: $prompt}]
      + if $screenshot == "" then [] else [{
          type: "file",
          mime: "image/png",
          filename: ($screenshot | split("/") | last),
          url: ("file://" + $screenshot)
        }] end)
  }
  + if $model == "" then {} else {
      model: {
        providerID: ($model | split("/")[0]),
        modelID: ($model | split("/")[1:] | join("/"))
      }
    } end')

response="$state/response-$$.json"
curl --silent --show-error --fail -X POST \
  -H 'Content-Type: application/json' \
  -d "$body" \
  "$(session_url /message)" >"$response" &
request_pid=$!
if ! wait "$request_pid"; then
  rm -f "$response"
  exit 1
fi
request_pid=""

reply=$(jq -r '[.parts[]? | select(.type == "text") | .text] | join("\n")' "$response")
error=$(jq -r '.info.error.data.message // empty' "$response")
rm -f "$response"

if [[ -z "$reply" ]]; then
  [[ -n "$error" ]] && printf '%s\n' "$error" >&2
  exit 1
fi

printf '%s\n' "$reply"

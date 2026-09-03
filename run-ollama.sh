#!/usr/bin/env bash
set -uo pipefail

model=${1-}
prompt=${2-}
screenshot=${3-}

if [[ -z "$model" || -z "$prompt" ]]; then
  printf 'Usage: run-ollama.sh <model> <prompt> [screenshot]\n' >&2
  exit 1
fi

payload_file=$(mktemp)
image_file=""
response_file=$(mktemp)
cleanup() {
  rm -f "$payload_file" "$response_file"
  [[ -z "$image_file" ]] || rm -f "$image_file"
}
trap cleanup EXIT

if [[ -n "$screenshot" && -f "$screenshot" ]]; then
  image_file=$(mktemp)
  base64 -w0 "$screenshot" > "$image_file"
  jq -n --arg model "$model" --arg prompt "$prompt" --rawfile image "$image_file" '{
    model: $model,
    messages: [{ role: "user", content: $prompt, images: [$image] }],
    stream: false
  }' > "$payload_file"
else
  jq -n --arg model "$model" --arg prompt "$prompt" '{
    model: $model,
    messages: [{ role: "user", content: $prompt }],
    stream: false
  }' > "$payload_file"
fi

if ! curl --silent --show-error --fail-with-body --max-time 600 \
  http://localhost:11434/api/chat -d @"$payload_file" > "$response_file"; then
  jq -r '.error // "Ollama did not respond before the request timed out."' "$response_file" >&2 2>/dev/null \
    || printf 'Ollama did not respond before the request timed out.\n' >&2
  exit 1
fi

reply=$(jq -r '.message.content // empty' "$response_file")

if [[ -z "$reply" ]]; then
  jq -r '.error // "No response from Ollama."' "$response_file" >&2
  exit 1
fi

printf '%s\n' "$reply"

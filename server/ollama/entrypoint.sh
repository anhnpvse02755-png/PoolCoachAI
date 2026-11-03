#!/bin/sh
set -eu

model="${OLLAMA_MODEL:-qwen2.5:3b}"
OLLAMA_HOST=0.0.0.0:11434 ollama serve &
server_pid=$!

cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

attempt=0
until OLLAMA_HOST=127.0.0.1:11434 ollama list >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "Ollama did not become ready" >&2
    exit 1
  fi
  sleep 1
done

OLLAMA_HOST=127.0.0.1:11434 ollama pull "$model"
wait "$server_pid"

FROM ollama/ollama:latest

ENV OLLAMA_HOST=0.0.0.0:11434
ENV OLLAMA_MODEL=qwen2.5:3b

COPY entrypoint.sh /usr/local/bin/poolcoachai-ollama-entrypoint
ENTRYPOINT ["/bin/sh", "/usr/local/bin/poolcoachai-ollama-entrypoint"]
EXPOSE 11434

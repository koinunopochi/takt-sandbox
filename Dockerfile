FROM node:20-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code takt

WORKDIR /workspace

ENTRYPOINT ["takt"]

FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends docker.io \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir terminal-bench pyyaml

COPY run_terminal_bench.py .

ENTRYPOINT []

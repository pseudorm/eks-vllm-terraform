FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY run_perf_benchmark.py aggregate_perf_results.py run_capability_eval.py ./

ENTRYPOINT []

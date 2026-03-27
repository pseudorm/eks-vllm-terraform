docker run --rm -d \
  --name vllm-server \
  --runtime=nvidia \
  --gpus all \
  -p 8000:8000 \
  --shm-size 8g \
  -v /mnt/vllm-models:/mnt/vllm-models \
  -e CUDA_VISIBLE_DEVICES=0 \
  vllm/vllm-openai:latest-cu130 \
  --model Qwen/Qwen3.5-9B \
  --download-dir /mnt/vllm-models \
  --tensor-parallel-size 1 \
  --max-model-len 4096 \
  --reasoning-parser qwen3 \
  --language-model-only \
  --gpu-memory-utilization 0.95 \
  --max-cudagraph-capture-size 64 \
  --dtype bfloat16
# clone repo
git clone https://github.com/langfuse/langfuse.git
cd langfuse

# checkout production branch
# main branch includes unreleased changes that might be unstable
git checkout production

export GOPROXY=direct
# build image with NEXT_PUBLIC_BASE_PATH
docker build -t 169446447120.dkr.ecr.ap-east-1.amazonaws.com/langfuse:latest \
    --build-arg GOPROXY=direct \
    --build-arg NEXT_PUBLIC_BASE_PATH=/langfuse \
    -f ./web/Dockerfile .


aws ecr get-login-password --region ap-east-1 | docker login --username AWS --password-stdin 169446447120.dkr.ecr.ap-east-1.amazonaws.com

docker push 169446447120.dkr.ecr.ap-east-1.amazonaws.com/langfuse:latest

#!/usr/bin/env bash
# Pre-bake everything the live demos need so they run offline.
# Run this with internet, before the talk. Then turn the Wi-Fi off and replay
# RUNBOOK.md to prove it.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> checking tools"
for t in docker hadolint dive syft grype cosign; do
  command -v "$t" >/dev/null || { echo "missing: $t (try: mise install)"; exit 1; }
done

echo "==> pulling base images"
for img in node:latest node:22 node:22-slim node:22-alpine \
  gcr.io/distroless/nodejs22-debian12 golang:1.26 debian:12-slim registry:2; do
  docker pull "$img"
done

echo "==> warming build caches"
docker build -t orders-api:naive .
docker build -f Dockerfile.hardened -t orders-api:hardened .
docker build -t go-svc:latest go-svc/

echo "==> updating grype vulnerability db"
grype db update

echo "==> starting local registry on :5000"
if ! docker ps --format '{{.Names}}' | grep -q '^sss-registry$'; then
  docker run -d --restart=always -p 5000:5000 --name sss-registry registry:2
fi

echo "==> pushing hardened image to the local registry"
docker tag orders-api:hardened localhost:5000/orders-api:latest
docker push localhost:5000/orders-api:latest

if [ ! -f cosign.key ]; then
  echo "==> generating cosign keypair (empty password; demo only)"
  COSIGN_PASSWORD="" cosign generate-key-pair
fi

echo "==> done. Digest for the cosign demo:"
docker inspect localhost:5000/orders-api:latest --format '{{index .RepoDigests 0}}'

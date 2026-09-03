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
  gcr.io/distroless/nodejs22-debian13 golang:1.26 debian:12-slim registry:2; do
  docker pull "$img"
done

echo "==> warming build caches"
docker build -t orders-api:naive .
docker build -f Dockerfile.hardened -t orders-api:hardened .
docker build -t go-svc:latest go-svc/

echo "==> updating grype vulnerability db"
grype db update

echo "==> starting local registry on :5001 (macOS AirPlay squats on 5000)"
if ! docker ps --format '{{.Names}}' | grep -q '^sss-registry$'; then
  docker run -d --restart=always -p 5001:5000 --name sss-registry registry:2
fi

echo "==> pushing images to the local registry"
docker tag orders-api:hardened localhost:5001/orders-api:latest
docker push localhost:5001/orders-api:latest

# demo 7 re-points this tag on stage; reset restores it
docker tag orders-api:hardened localhost:5001/orders-api:v1.0.1
docker push localhost:5001/orders-api:v1.0.1

# demo 9 signs this one: a real pile of CVEs, signed and verifiable
docker tag orders-api:naive localhost:5001/orders-api-naive:latest
docker push localhost:5001/orders-api-naive:latest

if [ ! -f cosign.key ]; then
  echo "==> generating cosign keypair (empty password; demo only)"
  COSIGN_PASSWORD="" cosign generate-key-pair
fi

if [ ! -f attacker.key ]; then
  echo "==> generating the attacker keypair (demo 8; empty password)"
  COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix attacker
fi

# RepoDigests order is not stable and one entry has no registry, so take the
# digest and rebuild the reference by hand.
digest_of() {
  local ref="$1"
  echo "${ref%:*}@$(docker inspect "$ref" --format '{{index .RepoDigests 0}}' | cut -d@ -f2)"
}

HARDENED=$(digest_of localhost:5001/orders-api:latest)
NAIVE=$(digest_of localhost:5001/orders-api-naive:latest)

echo "==> writing SBOMs if demo 4 hasn't run yet"
[ -f sbom-hardened.json ] || syft orders-api:hardened -o cyclonedx-json > sbom-hardened.json
[ -f sbom-naive.json ] || syft orders-api:naive -o cyclonedx-json > sbom-naive.json

echo "==> signing (needs network for the transparency log; verification is offline)"
COSIGN_PASSWORD="" cosign sign --key cosign.key --yes "$HARDENED"
COSIGN_PASSWORD="" cosign attest --key cosign.key --yes --type cyclonedx \
  --predicate sbom-hardened.json "$HARDENED"

# demo 8: the same image, signed by someone who is not you
COSIGN_PASSWORD="" cosign sign --key attacker.key --yes "$HARDENED"

# demo 9: sign and attest the naive image
COSIGN_PASSWORD="" cosign sign --key cosign.key --yes "$NAIVE"
COSIGN_PASSWORD="" cosign attest --key cosign.key --yes --type cyclonedx \
  --predicate sbom-naive.json "$NAIVE"

echo "==> done."
echo "    hardened: $HARDENED"
echo "    naive:    $NAIVE"
echo "    cluster demo (demo 10): ./scripts/cluster.sh"

#!/usr/bin/env bash
# Build the kind cluster demo 10 runs against: Kyverno plus the signed-images
# policy. Run this with internet, before the talk. Idempotent: safe to re-run.
set -euo pipefail

cd "$(dirname "$0")/.."

CLUSTER=sss
CTX="kind-${CLUSTER}"
KYVERNO_VERSION=v1.19.0

echo "==> checking tools"
for t in docker kind kubectl helm; do
  command -v "$t" >/dev/null || { echo "missing: $t (try: mise install)"; exit 1; }
done

if ! kind get clusters | grep -q "^${CLUSTER}$"; then
  echo "==> creating kind cluster ${CLUSTER}"
  kind create cluster --name "$CLUSTER"
fi

if ! kubectl --context "$CTX" get ns kyverno >/dev/null 2>&1; then
  echo "==> installing kyverno ${KYVERNO_VERSION}"
  helm repo add kyverno https://kyverno.github.io/kyverno >/dev/null
  helm repo update >/dev/null
  helm install kyverno kyverno/kyverno \
    --kube-context "$CTX" \
    --namespace kyverno --create-namespace \
    --version "${KYVERNO_VERSION#v}" \
    --wait
fi

echo "==> waiting for kyverno to be ready"
kubectl --context "$CTX" -n kyverno wait --for=condition=Available \
  deploy/kyverno-admission-controller --timeout=180s

echo "==> applying the policy"
kubectl --context "$CTX" apply -f policy/require-signed-images.yaml

# ghcr.io/thezmc/orders-api and /cryptominer are public, so Kyverno pulls the
# manifests anonymously. A private package would need a pull secret here and a
# spec.credentials.secrets patch on the policy.

echo "==> done. Replay demo 10 from RUNBOOK.md."

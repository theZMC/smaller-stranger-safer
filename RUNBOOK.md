# Runbook

The ten live demos, in slide order. Run `./scripts/prebake.sh` first (with
internet). Everything below works offline.

## Pre-bake checklist (before the talk)

- [ ] `./scripts/prebake.sh` ran clean
- [ ] `docker images` shows `orders-api:naive`, `orders-api:hardened`, and all
      bases
- [ ] `grype db status` shows a recent db
- [ ] local registry up: `curl -s localhost:5001/v2/_catalog` lists `orders-api`
- [ ] `cosign.key` / `cosign.pub` and `attacker.key` / `attacker.pub` exist
- [ ] registry has `orders-api:latest`, `orders-api:v1.0.1`,
      `orders-api-naive:latest`
- [ ] `./scripts/cluster.sh` ran clean; `kubectl get ivpol` shows
      `require-signed-images` ready
- [ ] terminal font size cranked, shell prompt minimal

## Demo 1: hadolint

```console
hadolint Dockerfile
```

## Demo 2: the damage

```console
docker build -t orders-api:naive .
docker images orders-api
dive orders-api:naive
```

## Demo 3: the diet

```console
docker build -f Dockerfile.hardened -t orders-api:hardened .
docker images orders-api
dive orders-api:hardened
```

## Demo 4: syft

```console
syft orders-api:naive -o cyclonedx-json > sbom-naive.json
syft orders-api:hardened -o cyclonedx-json > sbom-hardened.json
```

## Demo 5: grype

```console
grype sbom:./sbom-naive.json
grype sbom:./sbom-hardened.json
```

## Demo 6: cosign (keyed)

```console
DIGEST=localhost:5001/orders-api@$(docker inspect localhost:5001/orders-api:latest --format '{{index .RepoDigests 0}}' | cut -d@ -f2)
export COSIGN_PASSWORD=""    # prebake generated the key with an empty password
cosign sign --key cosign.key "$DIGEST"
cosign attest --key cosign.key --type cyclonedx --predicate sbom-hardened.json "$DIGEST"
cosign verify --key cosign.pub "$DIGEST"
```

## Demo 7: tags move, digests don't

```console
cosign verify --key cosign.pub localhost:5001/orders-api:v1.0.1
docker tag ghcr.io/thezmc/cryptominer localhost:5001/orders-api:v1.0.1
docker push localhost:5001/orders-api:v1.0.1
cosign verify --key cosign.pub localhost:5001/orders-api:v1.0.1
cosign verify --key cosign.pub "$DIGEST"
```

## Demo 8: a valid signature is not the right signer

```console
cosign verify --key cosign.pub "$DIGEST"
cosign verify --key attacker.pub "$DIGEST"
```

## Demo 9: signed is not safe

```console
NAIVE=localhost:5001/orders-api-naive@$(docker inspect localhost:5001/orders-api-naive:latest --format '{{index .RepoDigests 0}}' | cut -d@ -f2)
cosign verify --key cosign.pub "$NAIVE"
cosign verify-attestation --key cosign.pub --type cyclonedx "$NAIVE" \
  | jq -r '.payload' | base64 -d | jq '.predicate' > attested-naive.json
grype sbom:./attested-naive.json
```

## Demo 10: check it where it runs

```console
kubectl delete ivpol require-signed-images
kubectl apply -f k8s/unsigned-pod.yaml
kubectl apply -f policy/require-signed-images.yaml
kubectl delete pod oops
kubectl apply -f k8s/unsigned-pod.yaml
kubectl apply -f k8s/signed-pod.yaml
```

## Reset between rehearsals

```console
docker tag localhost:5001/orders-api:latest localhost:5001/orders-api:v1.0.1  # undo demo 7
docker push localhost:5001/orders-api:v1.0.1
kubectl delete pod oops ok --ignore-not-found                     # undo demo 10
kubectl apply -f policy/require-signed-images.yaml
docker rmi orders-api:naive orders-api:hardened
docker builder prune -f        # only if you want cold-cache timings
rm -f sbom-*.json attested-naive.json
```

Demo 7 leaves `:v1.0.1` pointing at the cryptominer image, so restore it before
the next rehearsal or demo 7 opens on a failure instead of a pass. Retag from
`localhost:5001/orders-api:latest`, not from the local `orders-api:hardened`:
rebuilding produces a new digest even from identical source, so a retag after
`docker rmi` and a rebuild would restore an unsigned image and demo 7 would open
on `no signatures found`.

The registry keeps its signatures; `docker rm -f sss-registry` and re-run
prebake for a truly clean slate.

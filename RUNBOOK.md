# Runbook

The six live demos, in slide order. Run `./scripts/prebake.sh` first (with
internet). Everything below works offline.

## Pre-bake checklist (before the talk)

- [ ] `./scripts/prebake.sh` ran clean
- [ ] `docker images` shows `orders-api:naive`, `orders-api:hardened`, and all bases
- [ ] `grype db status` shows a recent db
- [ ] local registry up: `curl -s localhost:5000/v2/_catalog` lists `orders-api`
- [ ] `cosign.key` / `cosign.pub` exist in the repo root
- [ ] terminal font size cranked, shell prompt minimal

## Demo 1: hadolint

```console
hadolint Dockerfile
```

Findings fire against the naive Dockerfile. No build, no network.

## Demo 2: the damage

```console
docker build -t orders-api:naive .
docker images orders-api
dive orders-api:naive
```

In dive: base layers dwarf the app; find the `COPY . .` layer and pause on
`.env`. Note the efficiency score and wasted space at the bottom.

## Demo 3: the diet

```console
docker build -f Dockerfile.hardened -t orders-api:hardened .
docker images orders-api
dive orders-api:hardened
```

Side-by-side sizes, then dive: no `COPY . .` layer, no dev deps, no OS
packages beyond the runtime.

## Demo 4: syft

```console
syft orders-api:naive -o cyclonedx-json > sbom-naive.json
syft orders-api:hardened -o cyclonedx-json > sbom-hardened.json
```

Peek inside the JSON: names, versions, licenses, package URLs.

## Demo 5: grype

```console
grype sbom:./sbom-naive.json
grype sbom:./sbom-hardened.json
```

grype reads the SBOM files from demo 4, not the images.

## Demo 6: cosign (keyed)

```console
DIGEST=$(docker inspect localhost:5000/orders-api:latest --format '{{index .RepoDigests 0}}')
cosign sign --key cosign.key "$DIGEST"
cosign attest --key cosign.key --type cyclonedx --predicate sbom-hardened.json "$DIGEST"
cosign verify --key cosign.pub "$DIGEST"
```

Keyed flow on the local registry: works air-gapped.

## Reset between rehearsals

```console
docker rmi orders-api:naive orders-api:hardened
docker builder prune -f        # only if you want cold-cache timings
rm -f sbom-*.json
```

The registry keeps its signatures; `docker rm -f sss-registry` and re-run
prebake for a truly clean slate.

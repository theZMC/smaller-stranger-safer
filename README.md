# Smaller, Stranger, Safer

Demo code for the talk **Smaller, Stranger, Safer: a field guide to container
security**, given at [Arkansec](https://arkansec.com) on 2026-09-03. Slides:
[zmc.dev/talks/smaller-stranger-safer](https://zmc.dev/talks/smaller-stranger-safer).

> This repo is private until the talk. If you can read this and it's after
> 2026-09-03, it worked.

The demo app is **orders-api**, a deliberately boring Express service. The point
of the talk is that the size and the CVEs come from the base image and the
packaging, not from your code.

## What's here

| Path                                | What it is                                                      |
| ----------------------------------- | --------------------------------------------------------------- |
| `Dockerfile`                        | The naive build everyone writes first. Bad on purpose.          |
| `Dockerfile.hardened`               | Multi-stage, digest-pinned, distroless, non-root.               |
| `Dockerfile.hardened.dockerignore`  | BuildKit per-Dockerfile ignore; the naive build gets no ignore. |
| `.env`                              | Fake secrets, committed on purpose, so `dive` can catch them.   |
| `go-svc/`                           | The `FROM scratch` Go cameo.                                    |
| `policy/require-signed-images.yaml` | Full Kyverno ImageValidatingPolicy the talk shows trimmed.      |
| `.github/workflows/release.yml`     | Keyless cosign sign + attest on every tag.                      |
| `.github/workflows/ci.yml`          | hadolint gate + grype gate.                                     |
| `RUNBOOK.md`                        | The six live demos, in order, with the pre-bake checklist.      |
| `captures/`                         | Real outputs captured for the slides.                           |

## Replaying the demos

Tools: `docker`, plus `hadolint`, `dive`, `syft`, `grype`, `cosign`, `kind`.
With [mise](https://mise.jdx.dev): `mise install`. With `brew`:
`brew install hadolint dive syft grype cosign kind`

```console
$ ./scripts/prebake.sh   # with internet: pulls bases, warms caches, starts a local registry, signs
$ ./scripts/cluster.sh   # with internet: kind cluster + Kyverno + the policy (demo 10 only)
```

Then follow [RUNBOOK.md](RUNBOOK.md). Everything after prebake runs offline.

FROM golang:1.26@sha256:45a5f7a810238aabcbad211d70b9ae082022d96f7c7259e94041ad1b933575ac AS build
WORKDIR /src
COPY go.mod ./
COPY cmd/ ./cmd/
RUN CGO_ENABLED=0 go build -o /svc ./cmd/svc

FROM debian:12-slim@sha256:abd67ffcfa541b485a3dff59865ab629aa048a6c613e639d36e7456b0b229241 AS certs
RUN apt-get update && apt-get install -y ca-certificates

FROM scratch
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /svc /svc
ENTRYPOINT ["/svc"]

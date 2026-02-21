# ASM Web Service

Minimal HTTP server in assembly (x86_64 and ARM64), runs in Docker (scratch) and Kubernetes.

## Routes

- **GET /** — HTML page with project info (GitHub link, binary size, image size).
- **GET /health** — Plain text `OK` for K8s liveness/readiness probes.

## Build and run locally

```powershell
docker build -t asm-server:latest .
docker run --rm -p 8080:8080 asm-server:latest
```

Or with docker-compose:

```powershell
docker-compose up --build
```

Then open http://localhost:8080/ and http://localhost:8080/health .

## Multi-arch (buildx)

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t asm-server:latest .
```

## Kubernetes

```bash
kubectl apply -f k8s/
```

Deployment uses image `asm-server:latest`. Load the image into the cluster (e.g. `kind load docker-image asm-server:latest` or push to your registry and set `image:` in `k8s/deployment.yaml`). Liveness and readiness probes use `GET /health`.

## Structure

- `src/main.asm` — x86_64 (NASM)
- `src/main.S` — ARM64 (GAS)
- `scripts/patch_binary.sh` — Injects binary/image size and GitHub URL at build time
- `Dockerfile` — Multi-stage, final image is `scratch`
- `static/index.html` — static page for GET / (embedded into binary at build time)
- `k8s/` — Deployment and Service

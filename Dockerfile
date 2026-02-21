# syntax=docker/dockerfile:1
# Multi-stage, multi-arch. Final image: scratch.
ARG TARGETARCH=amd64
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    nasm \
    binutils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY src/ /build/src/
COPY scripts/ /build/scripts/
COPY static/ /build/static/
RUN tr -d '\r' < /build/scripts/embed-static.sh > /tmp/embed-static.sh && chmod +x /tmp/embed-static.sh && /tmp/embed-static.sh /build

# Build for amd64 (x86_64). Route /health: check byte 12 is space.
FROM builder AS builder-amd64
RUN cd /build/src && nasm -f elf64 -o /build/main.o main.asm && \
    ld -static -nostdlib -e _start -o /build/server /build/main.o

# Build for arm64
FROM builder AS builder-arm64
RUN apt-get update && apt-get install -y --no-install-recommends gcc-aarch64-linux-gnu \
    && rm -rf /var/lib/apt/lists/*
RUN cd /build/src && aarch64-linux-gnu-as -o /build/main.o main.S && \
    aarch64-linux-gnu-ld -static -nostdlib -e _start -o /build/server /build/main.o

# Select builder output by arch
FROM builder-${TARGETARCH} AS artifact
ARG BINARY_SIZE
ARG IMAGE_SIZE=N/A
ARG GITHUB_URL=https://github.com/your-org/asm-server
COPY scripts/patch_binary.sh /build/patch_binary.sh
RUN tr -d '\r' < /build/patch_binary.sh > /tmp/p.sh && mv /tmp/p.sh /build/patch_binary.sh && chmod +x /build/patch_binary.sh && \
    BINARY_SIZE="${BINARY_SIZE:-$(stat -c%s /build/server)}" \
    IMAGE_SIZE="${IMAGE_SIZE}" \
    GITHUB_URL="${GITHUB_URL}" \
    /build/patch_binary.sh /build/server || true

FROM scratch
COPY --from=artifact /build/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]

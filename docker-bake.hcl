# docker buildx bake
# Usage: docker buildx bake [target|group]
# Supported by this Dockerfile: amd64, arm64. Others need builder-* stage in Dockerfile.

variable "IMAGE" {
  default = "reg.serabass.kz/vibecoding/asm-server"
}

variable "TAG" {
  default = "latest"
}

# Pass from host: docker buildx bake --set GITHUB_URL=$(git remote get-url origin)
variable "GITHUB_URL" {
  default = "https://github.com/Serabass/ASM-Web-Server"
}

# All platforms that buildx / OCI typically support
variable "PLATFORMS_ALL" {
  default = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
    "linux/386",
    "linux/ppc64le",
    "linux/s390x"
  ]
}

# Platforms we have ASM sources and builder for
variable "PLATFORMS_SUPPORTED" {
  default = [
    "linux/amd64",
    "linux/arm64"
  ]
}

group "default" {
  targets = ["asm-server"]
}

# Build only amd64 + arm64 (works with current Dockerfile)
target "asm-server" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS_SUPPORTED
  tags       = ["${IMAGE}:${TAG}"]
  output     = ["type=image"]
  args       = { GITHUB_URL = GITHUB_URL }
}

# Build for all listed platforms (will fail for arm/v7, 386, ppc64le, s390x until you add builder-* stages)
target "asm-server-all" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS_ALL
  tags       = ["${IMAGE}:${TAG}"]
  output     = ["type=image"]
  args       = { GITHUB_URL = GITHUB_URL }
}

# Push to registry (set REGISTRY or use full image name)
group "push" {
  targets = ["asm-server-push"]
}

target "asm-server-push" {
  inherits   = ["asm-server"]
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS_SUPPORTED
  tags       = ["${IMAGE}:${TAG}"]
  output     = ["type=registry"]
  args       = { GITHUB_URL = GITHUB_URL }
}

# Build image with GITHUB_URL from git remote (no cache, pass-through args to bake).
# Usage: .\scripts\build.ps1 [bake targets...]
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Push-Location $root
try {
  $gitUrl = ''
  try {
    $gitUrl = (git remote get-url origin 2>$null)
  } catch {}
  if (-not $gitUrl) { $gitUrl = '' }
  $setArg = "asm-server.args.GITHUB_URL=$gitUrl"
  & docker buildx bake --set $setArg @args
} finally {
  Pop-Location
}

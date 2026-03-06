# Build image with GITHUB_URL from git and IMAGE_SIZE from built image (two-phase: build -> get size -> rebuild with size).
# Usage: .\scripts\build.ps1 [bake targets...]
# For push: first builds asm-server locally to get image size, then builds and pushes the requested target with that size.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Push-Location $root
try {
  $gitUrl = ''
  try { $gitUrl = (git remote get-url origin 2>$null) } catch {}
  if (-not $gitUrl) { $gitUrl = '' }
  if ($gitUrl -match '^(.+)\.git$') { $gitUrl = $Matches[1] }
  $imgName = if ($env:BAKE_IMAGE) { "$env:BAKE_IMAGE}:$(if ($env:BAKE_TAG) { $env:BAKE_TAG } else { 'latest' })" } else { 'reg.serabass.kz/vibecoding/asm-server:latest' }
  $setArg = "asm-server.args.GITHUB_URL=$gitUrl"

  # Build single-platform (amd64) with load so we can measure image size. type=image multi-platform does not load.
  Write-Host "Building amd64 image to measure size..."
  $null = docker buildx build --platform linux/amd64 -f Dockerfile `
    --build-arg "GITHUB_URL=$gitUrl" --build-arg "IMAGE_SIZE=N/A" `
    -t $imgName --load .
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $sizeBytes = $null
  $out = docker image inspect $imgName --format '{{.Size}}' 2>$null
  if ($out -match '^\d+$') { $sizeBytes = [long]$out }
  $imgSizeStr = 'N/A'
  if ($sizeBytes -and $sizeBytes -gt 0) {
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($sizeBytes -ge 1MB) { $imgSizeStr = [string]::Format($inv, '{0:N2} MiB', [decimal]($sizeBytes / 1MB)) }
    elseif ($sizeBytes -ge 1KB) { $imgSizeStr = [string]::Format($inv, '{0:N2} KiB', [decimal]($sizeBytes / 1KB)) }
    else { $imgSizeStr = "$sizeBytes bytes" }
    Write-Host "Image size: $imgSizeStr"
  }

  $setArg2 = "asm-server.args.IMAGE_SIZE=$imgSizeStr"
  Write-Host "Building with IMAGE_SIZE=$imgSizeStr..."
  & docker buildx bake --set $setArg --set $setArg2 @args
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  # Update README: replace value after <!--IMGSIZE--> with current size
  $readmePath = Join-Path $root 'README.md'
  if (Test-Path $readmePath) {
    $content = Get-Content $readmePath -Raw -Encoding UTF8
    $content = $content -replace '(<!--IMGSIZE-->)\s*[^\r\n]*', "`${1} $imgSizeStr"
    [System.IO.File]::WriteAllText((Resolve-Path $readmePath).Path, $content, [System.Text.UTF8Encoding]::new($false))
  }
} finally {
  Pop-Location
}

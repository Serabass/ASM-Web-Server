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

  # If target is push, build asm-server first (loads to local) so we can read image size; push target does not load locally.
  $isPush = ($args -match 'asm-server-push|^push$')
  if ($isPush) {
    & docker buildx bake --set $setArg asm-server
  } else {
    & docker buildx bake --set $setArg @args
  }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  # Get image size (bytes). Only available when image was loaded locally (asm-server or after we built asm-server above).
  $sizeBytes = $null
  $out = docker image inspect $imgName --format '{{.Size}}' 2>$null
  if ($out -match '^\d+$') { $sizeBytes = [long]$out }
  if (-not $sizeBytes -or $sizeBytes -eq 0) {
    $raw = docker buildx imagetools inspect $imgName --format '{{json .}}' 2>$null
    if ($raw) {
      $j = $raw | ConvertFrom-Json
      if ($j.Manifests -and $j.Manifests.Count -gt 0 -and $j.Manifests[0].Size) { $sizeBytes = [long]$j.Manifests[0].Size }
    }
  }
  $imgSizeStr = 'N/A'
  if ($sizeBytes -and $sizeBytes -gt 0) {
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($sizeBytes -ge 1MB) { $imgSizeStr = [string]::Format($inv, '{0:N2} MiB', [decimal]($sizeBytes / 1MB)) }
    elseif ($sizeBytes -ge 1KB) { $imgSizeStr = [string]::Format($inv, '{0:N2} KiB', [decimal]($sizeBytes / 1KB)) }
    else { $imgSizeStr = "$sizeBytes bytes" }
  }

  # Second build with IMAGE_SIZE so the binary and README get the real size
  $setArg2 = "asm-server.args.IMAGE_SIZE=$imgSizeStr"
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

# Build image and restart the local Docker container.
# Container name: asm-server, port: 8080 (fallback 9191 if 8080 is in use)
# Usage: .\scripts\deploy-docker.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Image = 'reg.serabass.kz/vibecoding/asm-server:latest'
$ContainerName = 'asm-server'
$PortHost = 8080
$PortContainer = 8080

Push-Location $root
try {
  Write-Host "Building image..."
  & (Join-Path $root 'scripts\build.ps1')
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "Stopping and removing existing container (if any)..."
  docker rm -f $ContainerName 2>$null

  Write-Host "Starting container..."
  docker run -d -p "${PortHost}:${PortContainer}" --name $ContainerName $Image 2>$null
  if ($LASTEXITCODE -ne 0 -and $PortHost -eq 8080) {
    docker rm -f $ContainerName 2>$null
    $PortHost = 9191
    Write-Host "Port 8080 in use, using $PortHost..."
    docker run -d -p "${PortHost}:${PortContainer}" --name $ContainerName $Image
  }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Start-Sleep -Seconds 1
  docker ps --filter "name=$ContainerName"
  Write-Host "Done. http://localhost:$PortHost/"
} finally {
  Pop-Location
}

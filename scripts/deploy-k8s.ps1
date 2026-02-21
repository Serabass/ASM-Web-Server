# Build image (with push to registry), then restart the Kubernetes deployment.
# Namespace: vibecoding, Deployment: asm-server
# Usage: .\scripts\deploy-k8s.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Namespace = 'vibecoding'
$Deployment = 'asm-server'

Push-Location $root
try {
  Write-Host "Building and pushing image..."
  & (Join-Path $root 'scripts\build.ps1') asm-server-push
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "Restarting deployment/$Deployment in namespace $Namespace..."
  kubectl rollout restart "deployment/$Deployment" -n $Namespace
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  kubectl rollout status "deployment/$Deployment" -n $Namespace --timeout=120s
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host "Done. deployment/$Deployment restarted."
} finally {
  Pop-Location
}

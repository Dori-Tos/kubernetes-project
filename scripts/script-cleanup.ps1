# Simple Cleanup Script for Movie Rating Kubernetes Application

param(
    [switch]$KeepIngress,
    [switch]$Force
)

Write-Host "Cleaning up Movie Rating Application..." -ForegroundColor Yellow

# Show what will be deleted
Write-Host ""
Write-Host "Current resources:" -ForegroundColor Cyan
kubectl get pods,svc,ingress

# Confirm cleanup
if (-not $Force) {
    Write-Host ""
    $confirm = Read-Host "Continue with cleanup? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Cleanup cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Delete application resources
Write-Host ""
Write-Host "Removing application resources..." -ForegroundColor Yellow
kubectl delete -f kubernetes/ --ignore-not-found=true

# Wait for cleanup
Start-Sleep -Seconds 3

# Remove ingress controller if requested
if (-not $KeepIngress) {
    Write-Host "Removing ingress controller..." -ForegroundColor Yellow
    kubectl delete namespace ingress-nginx --ignore-not-found=true
    Write-Host "Ingress cleanup initiated (may take a moment to complete)" -ForegroundColor Yellow
} else {
    Write-Host "Keeping ingress controller (-KeepIngress used)" -ForegroundColor Blue
}

# Show final state
Write-Host ""
Write-Host "Remaining resources:" -ForegroundColor Cyan
kubectl get pods,svc,ingress

Write-Host ""
Write-Host "Cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage: .\script-cleanup.ps1 [-KeepIngress] [-Force]" -ForegroundColor Cyan

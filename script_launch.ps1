# Simple Launch Script for Movie Rating Kubernetes Application

-param(
    [switch]$Build
)

Write-Host "Launching Movie Rating Application..." -ForegroundColor Green

# Check if ingress namespace exists and wait if it's being deleted
$namespace = kubectl get namespace ingress-nginx --ignore-not-found=true 2>$null
if ($namespace -and $namespace -match "Terminating") {
    Write-Host "Waiting for previous ingress cleanup to complete..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 5
        $namespace = kubectl get namespace ingress-nginx --ignore-not-found=true 2>$null
        Write-Host "." -NoNewline
    } while ($namespace)
    Write-Host ""
    Write-Host "Previous cleanup complete" -ForegroundColor Green
}

(if ($Build) {
    Write-Host "Building images..." -ForegroundColor Yellow
    # Build images
    Write-Host "Building application image..." -ForegroundColor Yellow
    docker build -t app:1.0 .
    Write-Host "Building Varnish Cache image..." -ForegroundColor Yellow
    docker build -t varnish-cache:1.0 ./varnish/
} else {
    Write-Host "Skipping image build (-Build not used)" -ForegroundColor Blue
})

# Install ingress controller
Write-Host "Installing ingress controller..." -ForegroundColor Yellow
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller
Write-Host "Waiting for ingress controller..." -ForegroundColor Yellow
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s

# Deploy application
Write-Host "Deploying application..." -ForegroundColor Yellow
kubectl apply -f kubernetes/

# Deploy Varnish Cache
Write-Host "Deploying Varnish Cache..." -ForegroundColor Yellow
kubectl apply -f varnish/varnish-deployment.yaml

# Show status
Write-Host ""
Write-Host "Status:" -ForegroundColor Cyan
kubectl get pods,svc,ingress

Write-Host ""
Write-Host "Access your app:" -ForegroundColor Green
Write-Host "Test: Invoke-WebRequest -Uri http://localhost -Headers @{'Host'='movierating.local'}" -ForegroundColor White
Write-Host "URL: http://movierating.local (after adding to hosts file)" -ForegroundColor White

Write-Host ""
Write-Host "Launch complete!" -ForegroundColor Green

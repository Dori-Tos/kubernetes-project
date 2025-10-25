# MongoDB Multi-Namespace Setup Script (PowerShell)
# This script configures the MongoDB Community Operator for multi-namespace support

$ErrorActionPreference = "Stop"

Write-Host "🚀 Setting up MongoDB Community Operator for multi-namespace support..." -ForegroundColor Green

# Check if kubectl is available
try {
    kubectl version --client --short | Out-Null
} catch {
    Write-Host "❌ kubectl is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Function to check if resource exists
function ResourceExists($type, $name, $namespace) {
    try {
        kubectl get $type $name -n $namespace | Out-Null
        return $true
    } catch {
        return $false
    }
}

# 1. Apply cluster-wide RBAC permissions
Write-Host "📋 Applying cluster-wide RBAC permissions..." -ForegroundColor Yellow
kubectl apply -f mongodb-operator-cluster-permissions.yaml

# 2. Create required service accounts
Write-Host "👤 Creating required service accounts..." -ForegroundColor Yellow
kubectl apply -f mongodb-service-accounts.yaml

# 3. Check if MongoDB operator deployment exists
if (ResourceExists "deployment" "mongodb-kubernetes-operator" "default") {
    Write-Host "🔧 Patching MongoDB operator to watch all namespaces..." -ForegroundColor Yellow
    kubectl patch deployment mongodb-kubernetes-operator -n default --patch-file mongodb-operator-patch.yaml
    
    Write-Host "🔄 Restarting MongoDB operator..." -ForegroundColor Yellow
    kubectl rollout restart deployment/mongodb-kubernetes-operator -n default
    
    Write-Host "⏳ Waiting for operator to be ready..." -ForegroundColor Yellow
    kubectl rollout status deployment/mongodb-kubernetes-operator -n default --timeout=300s
} else {
    Write-Host "⚠️  MongoDB Community Operator not found. Please install it first." -ForegroundColor Red
    Write-Host "   Refer to the README.md for installation instructions." -ForegroundColor Red
    exit 1
}

# 4. Verification
Write-Host "✅ Verifying setup..." -ForegroundColor Yellow

# Wait a moment for operator to restart
Start-Sleep -Seconds 10

# Check operator logs for errors
Write-Host "📋 Checking operator logs..." -ForegroundColor Yellow
$logs = kubectl logs -n default deployment/mongodb-kubernetes-operator --tail=10
if ($logs -match "forbidden|error") {
    Write-Host "⚠️  Found errors in operator logs. Check permissions." -ForegroundColor Red
    kubectl logs -n default deployment/mongodb-kubernetes-operator --tail=20
} else {
    Write-Host "✅ Operator logs look good!" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 MongoDB multi-namespace setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now deploy MongoDB resources to any namespace." -ForegroundColor Cyan
Write-Host "The operator will automatically manage them." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Apply your MongoDB configurations (e.g., kubectl apply -k mongodb/prod/)" -ForegroundColor White
Write-Host "2. Monitor MongoDB pods: kubectl get pods -n production | Select-String mongodb" -ForegroundColor White
Write-Host "3. Check MongoDB status: kubectl get mongodbcommunity -n production" -ForegroundColor White
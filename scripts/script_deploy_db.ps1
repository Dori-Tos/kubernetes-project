# Load environment variables from .env file
Get-Content .env | ForEach-Object {
    if ($_ -match "^([^=]+)=(.*)$") {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

# Apply with environment variable substitution
$env:MONGODB_USERNAME = [Environment]::GetEnvironmentVariable("MONGODB_USERNAME")
$env:MONGODB_PASSWORD = [Environment]::GetEnvironmentVariable("MONGODB_PASSWORD") 
$env:MONGODB_TEST_DATABASE = [Environment]::GetEnvironmentVariable("MONGODB_TEST_DATABASE")

# Substitute variables in configmap and apply
(Get-Content kubernetes/app/app-configmap.yaml) | 
    ForEach-Object { $_ -replace '\$\{MONGODB_USERNAME\}', $env:MONGODB_USERNAME } |
    ForEach-Object { $_ -replace '\$\{MONGODB_PASSWORD\}', $env:MONGODB_PASSWORD } |
    ForEach-Object { $_ -replace '\$\{MONGODB_TEST_DATABASE\}', $env:MONGODB_TEST_DATABASE } |
    kubectl apply -f -

# Clean up first
Write-Host "Cleaning up existing deployments..."
kubectl delete mongodbcommunity --all -n test --ignore-not-found=true
kubectl delete deployment mongodb-kubernetes-operator -n test --ignore-not-found=true
kubectl delete pods -l name=mongodb-kubernetes-operator -n test --force --grace-period=0 --ignore-not-found=true
Start-Sleep -Seconds 10

# Apply CRDs first
Write-Host "Applying MongoDB CRDs..."
kubectl apply -f kubernetes/mongodb/mongodb-community-operator.yaml
Start-Sleep -Seconds 5

# Create secrets
Write-Host "Creating secrets..."
if (Test-Path "kubernetes/mongodb/mongodb-secret-template.yaml") {
    $secretTemplate = Get-Content kubernetes/mongodb/mongodb-secret-template.yaml -Raw
    $secretTemplate = $secretTemplate -replace '\$\{MONGODB_ADMIN_PASSWORD\}', $env:MONGODB_ADMIN_PASSWORD
    $secretTemplate = $secretTemplate -replace '\$\{MONGODB_APP_PASSWORD\}', $env:MONGODB_APP_PASSWORD
    $secretTemplate = $secretTemplate -replace '\$\{MONGODB_USERNAME\}', $env:MONGODB_USERNAME
    $secretTemplate = $secretTemplate -replace '\$\{MONGODB_TEST_DATABASE\}', $env:MONGODB_TEST_DATABASE

    $secretTemplate | kubectl apply -f -
} else {
    Write-Host "Creating secrets directly..."
    kubectl create secret generic mongodb-admin-password --from-literal=password="$env:MONGODB_ADMIN_PASSWORD" -n test --dry-run=client -o yaml | kubectl apply -f -
    kubectl create secret generic mongodb-app-password --from-literal=password="$env:MONGODB_APP_PASSWORD" -n test --dry-run=client -o yaml | kubectl apply -f -
}

# Apply operator
Write-Host "Applying MongoDB operator..."
kubectl apply -f kubernetes/mongodb/mongodb-operator.yaml

# Wait for operator to be ready
Write-Host "Waiting for operator to be ready..."
$attempts = 0
$maxAttempts = 12

do {
    $podName = kubectl get pods -l name=mongodb-kubernetes-operator -n test -o jsonpath='{.items[0].metadata.name}' 2>$null
    $podStatus = kubectl get pods -l name=mongodb-kubernetes-operator -n test -o jsonpath='{.items[0].status.phase}' 2>$null
    
    Write-Host "Attempt $($attempts + 1): Pod $podName - Status: $podStatus"
    
    if ($podStatus -eq "Running") {
        Write-Host "Operator is running!"
        break
    }
    
    Start-Sleep -Seconds 10
    $attempts++
} while ($attempts -lt $maxAttempts)

# Give the operator time to fully initialize
Write-Host "Waiting for operator to fully initialize..."
Start-Sleep -Seconds 15

# Apply MongoDB resources with environment variable substitution
Write-Host "Applying MongoDB resources with environment substitution..."

# Process replica set config
if (Test-Path "kubernetes/mongodb/mongodb-replica-set-config.yaml") {
    $replicaConfig = Get-Content kubernetes/mongodb/mongodb-replica-set-config.yaml -Raw
    $replicaConfig = $replicaConfig -replace '\$\{MONGODB_USERNAME\}', $env:MONGODB_USERNAME
    $replicaConfig = $replicaConfig -replace '\$\{MONGODB_TEST_DATABASE\}', $env:MONGODB_TEST_DATABASE
    
    $replicaConfig | kubectl apply -f -
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MongoDB replica set config applied successfully"
    } else {
        Write-Host "Failed to apply MongoDB replica set config"
        exit 1
    }
} else {
    Write-Host "mongodb-replica-set-config.yaml not found"
    exit 1
}

# Process router config
if (Test-Path "kubernetes/mongodb/mongodb-router.yaml") {
    $routerConfig = Get-Content kubernetes/mongodb/mongodb-router.yaml -Raw
    $routerConfig = $routerConfig -replace '\$\{MONGODB_USERNAME\}', $env:MONGODB_USERNAME
    $routerConfig = $routerConfig -replace '\$\{MONGODB_TEST_DATABASE\}', $env:MONGODB_TEST_DATABASE
    
    $routerConfig | kubectl apply -f -
    if ($LASTEXITCODE -eq 0) {
        Write-Host "MongoDB router applied successfully"
    } else {
        Write-Host "Failed to apply MongoDB router"
        exit 1
    }
}

Write-Host ""
Write-Host "MongoDB deployment initiated!"
Write-Host ""
Write-Host "Checking initial status..."
kubectl get mongodbcommunity -n test
Write-Host ""
Write-Host "Useful commands to monitor progress:"
Write-Host "kubectl get pods -n test"
Write-Host "kubectl get statefulsets -n test"
Write-Host "kubectl get mongodbcommunity -n test"
Write-Host "kubectl logs -l name=mongodb-kubernetes-operator -n test"
Write-Host "kubectl describe mongodbcommunity mongodb-config -n test"
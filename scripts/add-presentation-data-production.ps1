# PowerShell Script to Add Presentation Data to Production MongoDB
# This script adds sample movies, actors, and reviews for presentation purposes

Write-Host "=== Adding Presentation Data to Production MongoDB ===" -ForegroundColor Green

# Check prerequisites
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command mongoimport -ErrorAction SilentlyContinue)) {
    Write-Host "Error: mongoimport not found. Please install MongoDB tools first." -ForegroundColor Red
    exit 1
}

# Check if we can connect to production MongoDB via port forward
Write-Host "Setting up port forwarding to production MongoDB..." -ForegroundColor Yellow
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward -n production svc/production-mongodb-svc 27017:27017
}

# Wait a moment for port forward to establish
Start-Sleep -Seconds 5

try {
    # Connection string for port-forwarded connection
    $localConnectionString = "mongodb://app-user:appuser123@localhost:27017/app-production?authSource=admin"
    
    Write-Host "Adding actors..." -ForegroundColor Cyan
    $actorsResult = mongoimport --uri="$localConnectionString" --collection="actors" --file="presentation-data\actors-presentation.json" 2>&1
    Write-Host $actorsResult
    
    Write-Host "Adding movies..." -ForegroundColor Cyan
    $moviesResult = mongoimport --uri="$localConnectionString" --collection="movies" --file="presentation-data\movies-presentation.json" 2>&1
    Write-Host $moviesResult
    
    Write-Host "Adding reviews..." -ForegroundColor Cyan
    $reviewsResult = mongoimport --uri="$localConnectionString" --collection="reviews" --file="presentation-data\reviews-presentation.json" 2>&1
    Write-Host $reviewsResult
    
    Write-Host "=== Presentation Data Added Successfully! ===" -ForegroundColor Green
    
} catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
} finally {
    # Clean up port forward
    Write-Host "Cleaning up port forwarding..." -ForegroundColor Yellow
    Stop-Job $portForwardJob -ErrorAction SilentlyContinue
    Remove-Job $portForwardJob -ErrorAction SilentlyContinue
}

Write-Host "=== Script Completed ===" -ForegroundColor Green
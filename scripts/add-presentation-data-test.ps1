# PowerShell Script to Add Test Data to Default MongoDB (for testing purposes)
# This script adds the same sample data to test environment first

Write-Host "=== Adding Test Data to Default MongoDB ===" -ForegroundColor Green

# Check prerequisites
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command mongoimport -ErrorAction SilentlyContinue)) {
    Write-Host "Error: mongoimport not found. Please install MongoDB tools first." -ForegroundColor Red
    exit 1
}

# Check if we can connect to test MongoDB via port forward
Write-Host "Setting up port forwarding to test MongoDB..." -ForegroundColor Yellow
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward -n default svc/example-mongodb-svc 27018:27017
}

# Wait a moment for port forward to establish
Start-Sleep -Seconds 5

try {
    # Connection string for port-forwarded connection (using port 27018 to avoid conflicts)
    $localConnectionString = "mongodb://app-user:appuser123@localhost:27018/movie-ratings-db?authSource=admin"
    
    Write-Host "Adding actors to test environment..." -ForegroundColor Cyan
    $actorsResult = mongoimport --uri="$localConnectionString" --collection="actors" --file="presentation-data\actors-presentation.json" 2>&1
    Write-Host $actorsResult
    
    Write-Host "Adding movies to test environment..." -ForegroundColor Cyan
    $moviesResult = mongoimport --uri="$localConnectionString" --collection="movies" --file="presentation-data\movies-presentation.json" 2>&1
    Write-Host $moviesResult
    
    Write-Host "Adding reviews to test environment..." -ForegroundColor Cyan
    $reviewsResult = mongoimport --uri="$localConnectionString" --collection="reviews" --file="presentation-data\reviews-presentation.json" 2>&1 
    Write-Host $reviewsResult
    
    Write-Host "=== Test Data Added Successfully! ===" -ForegroundColor Green
    Write-Host "Test the application now to ensure everything works correctly." -ForegroundColor Yellow
    Write-Host "If everything looks good, run the production script next." -ForegroundColor Yellow
    
} catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
} finally {
    # Clean up port forward
    Write-Host "Cleaning up port forwarding..." -ForegroundColor Yellow
    Stop-Job $portForwardJob -ErrorAction SilentlyContinue
    Remove-Job $portForwardJob -ErrorAction SilentlyContinue
}

Write-Host "=== Script Completed ===" -ForegroundColor Green
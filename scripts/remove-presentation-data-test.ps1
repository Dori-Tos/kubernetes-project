# PowerShell Script to Remove Test Presentation Data from Default MongoDB
# This script removes the presentation data from test environment

Write-Host "=== Removing Test Presentation Data from Default MongoDB ===" -ForegroundColor Red

# Check prerequisites
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found. Please install kubectl first." -ForegroundColor Red
    exit 1
}

# Check for MongoDB shell (try mongosh first, then mongo as fallback)
$mongoCommand = $null
if (Get-Command mongosh -ErrorAction SilentlyContinue) {
    $mongoCommand = "mongosh"
    Write-Host "Using mongosh (modern MongoDB shell)" -ForegroundColor Green
} elseif (Get-Command mongo -ErrorAction SilentlyContinue) {
    $mongoCommand = "mongo"
    Write-Host "Using mongo (legacy MongoDB shell)" -ForegroundColor Yellow
} else {
    Write-Host "Error: Neither mongosh nor mongo command found. Please install MongoDB tools first." -ForegroundColor Red
    exit 1
}

# Setup port forwarding to test MongoDB
Write-Host "Setting up port forwarding to test MongoDB..." -ForegroundColor Yellow
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward -n default svc/example-mongodb-svc 27018:27017
}

# Wait a moment for port forward to establish
Start-Sleep -Seconds 5

try {
    # Connection string for port-forwarded connection
    $localConnectionString = "mongodb://app-user:appuser123@localhost:27018/movie-ratings-db?authSource=admin"
    
    # Get actual ObjectIds from presentation data files
    Write-Host "Reading ObjectIds from presentation data files..." -ForegroundColor Yellow
    
    # Extract ObjectIds from actors file
    $actorIds = @()
    if (Test-Path "presentation-data\actors-presentation.json") {
        $actorsContent = Get-Content "presentation-data\actors-presentation.json" -Raw
        $actorMatches = [regex]::Matches($actorsContent, '"70f4c08571726d7ff389b\w{3}"')
        foreach ($match in $actorMatches) {
            $actorIds += $match.Value.Trim('"')
        }
        $actorMatches = [regex]::Matches($actorsContent, '"82f4c08571726d7ff389b\w{3}"')
        foreach ($match in $actorMatches) {
            $actorIds += $match.Value.Trim('"')
        }
    }
    
    # Extract ObjectIds from movies file  
    $movieIds = @()
    if (Test-Path "presentation-data\movies-presentation.json") {
        $moviesContent = Get-Content "presentation-data\movies-presentation.json" -Raw
        $movieMatches = [regex]::Matches($moviesContent, '"70f4c08571726d7ff389b1\w{2}"')
        foreach ($match in $movieMatches) {
            $movieIds += $match.Value.Trim('"')
        }
    }
    
    # Extract ObjectIds from reviews file
    $reviewIds = @()
    if (Test-Path "presentation-data\reviews-presentation.json") {
        $reviewsContent = Get-Content "presentation-data\reviews-presentation.json" -Raw
        $reviewMatches = [regex]::Matches($reviewsContent, '"70f4c08571726d7ff389b2\w{2}"')
        foreach ($match in $reviewMatches) {
            $reviewIds += $match.Value.Trim('"')
        }
    }
    
    Write-Host "Found IDs - Actors: $($actorIds.Count), Movies: $($movieIds.Count), Reviews: $($reviewIds.Count)" -ForegroundColor Cyan
    
    # Remove actors
    if ($actorIds.Count -gt 0) {
        Write-Host "Removing presentation actors..." -ForegroundColor Cyan
        $actorIdList = ($actorIds | ForEach-Object { "ObjectId('$_')" }) -join ", "
        $removeActors = & $mongoCommand $localConnectionString --eval "db.actors.deleteMany({_id: {`$in: [$actorIdList]}})" 2>&1
        Write-Host $removeActors
    }
    
    # Remove movies
    if ($movieIds.Count -gt 0) {
        Write-Host "Removing presentation movies..." -ForegroundColor Cyan
        $movieIdList = ($movieIds | ForEach-Object { "ObjectId('$_')" }) -join ", "
        $removeMovies = & $mongoCommand $localConnectionString --eval "db.movies.deleteMany({_id: {`$in: [$movieIdList]}})" 2>&1
        Write-Host $removeMovies
    }
    
    # Remove reviews
    if ($reviewIds.Count -gt 0) {
        Write-Host "Removing presentation reviews..." -ForegroundColor Cyan
        $reviewIdList = ($reviewIds | ForEach-Object { "ObjectId('$_')" }) -join ", "
        $removeReviews = & $mongoCommand $localConnectionString --eval "db.reviews.deleteMany({_id: {`$in: [$reviewIdList]}})" 2>&1
        Write-Host $removeReviews
    }
    
    Write-Host "=== Test Presentation Data Removed Successfully! ===" -ForegroundColor Green
    Write-Host "The test environment is now clean of presentation data." -ForegroundColor Yellow
    
} catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
} finally {
    # Clean up port forward
    Write-Host "Cleaning up port forwarding..." -ForegroundColor Yellow
    Stop-Job $portForwardJob -ErrorAction SilentlyContinue
    Remove-Job $portForwardJob -ErrorAction SilentlyContinue
}

Write-Host "=== Script Completed ===" -ForegroundColor Green
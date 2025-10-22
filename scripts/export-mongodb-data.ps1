# MongoDB Data Export Script
# This script exports all data from your MongoDB to files for transfer

Write-Host "Starting MongoDB Data Export..." -ForegroundColor Green

# Create export directory
$exportDir = "mongodb-export"
if (Test-Path $exportDir) {
    Remove-Item $exportDir -Recurse -Force
}
New-Item -ItemType Directory -Path $exportDir

# Check if MongoDB tools are available
$hasMongoExport = Get-Command "mongoexport" -ErrorAction SilentlyContinue
$hasMongoDump = Get-Command "mongodump" -ErrorAction SilentlyContinue

if (-not $hasMongoExport -or -not $hasMongoDump) {
    Write-Host "❌ MongoDB Database Tools not found!" -ForegroundColor Red
    Write-Host "💡 Installing MongoDB Database Tools..." -ForegroundColor Yellow
    Write-Host "Please install from: https://www.mongodb.com/try/download/database-tools" -ForegroundColor Cyan
    Write-Host "Or using chocolatey: choco install mongodb-database-tools" -ForegroundColor Cyan
    Write-Host "" -ForegroundColor White
    Write-Host "🔄 Using alternative Python-based export..." -ForegroundColor Yellow
    
    # Use Python alternative
    .\export-python-alternative.ps1
    return
}

# Set up port forwarding to MongoDB (if not already running)
Write-Host "Setting up port forwarding..." -ForegroundColor Yellow
$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward pod/example-mongodb-0 27017:27017 -n test
}
Start-Sleep 5

try {
    # Get connection details (use app-user credentials that have access to movie-ratings-db)
    $connectionString = "mongodb://app-user:appuser123@localhost:27017/?authSource=admin&directConnection=true"
    $database = "movie-ratings-db"

    Write-Host "Exporting collections..." -ForegroundColor Cyan

    # Export each collection
    $collections = @("actors", "movies", "reviews")
    foreach ($collection in $collections) {
        Write-Host "Exporting $collection..." -ForegroundColor White
        
        # Export as JSON (human readable)
        mongoexport --uri="$connectionString" --db="$database" --collection="$collection" --out="$exportDir/$collection.json" --pretty
        
        # Export as BSON (binary, preserves types)
        mongodump --uri="$connectionString" --db="$database" --collection="$collection" --out="$exportDir/bson/"
    }

    # Export entire database structure
    Write-Host "Creating full database backup..." -ForegroundColor White
    mongodump --uri="$connectionString" --db="$database" --out="$exportDir/full-backup/"

    # Create import script
    $importScript = @"
# MongoDB Data Import Script
# Run this script on your new MongoDB system

# Note: Replace credentials below with your target system's credentials

# Option 1: Import individual JSON files
mongoimport --uri="mongodb://app-user:appuser123@localhost:27017/?authSource=admin" --db="movie-ratings-db" --collection="actors" --file="actors.json"
mongoimport --uri="mongodb://app-user:appuser123@localhost:27017/?authSource=admin" --db="movie-ratings-db" --collection="movies" --file="movies.json" 
mongoimport --uri="mongodb://app-user:appuser123@localhost:27017/?authSource=admin" --db="movie-ratings-db" --collection="reviews" --file="reviews.json"

# Option 2: Restore from BSON backup (preserves all data types and indexes)
mongorestore --uri="mongodb://app-user:appuser123@localhost:27017/?authSource=admin" --nsFrom="movie-ratings-db.*" --nsTo="movie-ratings-db.*" bson/

# Option 3: Restore entire database structure
mongorestore --uri="mongodb://app-user:appuser123@localhost:27017/?authSource=admin" full-backup/

# If your target system has different credentials, update the URI accordingly:
# Example: mongodb://your-username:your-password@your-host:27017/?authSource=admin
"@

    $importScript | Out-File -FilePath "$exportDir/import-instructions.txt" -Encoding UTF8

    Write-Host "`n✅ Export completed successfully!" -ForegroundColor Green
    Write-Host "📁 Files exported to: $exportDir" -ForegroundColor Yellow
    Write-Host "📋 Import instructions: $exportDir/import-instructions.txt" -ForegroundColor Cyan
    
    # Show what was exported
    Get-ChildItem $exportDir -Recurse | ForEach-Object {
        Write-Host "   $($_.FullName)" -ForegroundColor Gray
    }

} finally {
    # Clean up port forwarding (compatible with older PowerShell)
    if ($portForwardJob) {
        Stop-Job $portForwardJob
        Remove-Job $portForwardJob
    }
}
# MongoDB Import Script for New Database
# Use this to import data into a completely new MongoDB instance

param(
    [Parameter(Mandatory=$true)]
    [string]$ConnectionString,
    
    [string]$ImportDirectory = "mongodb-export",
    
    [switch]$DropExisting
)

Write-Host "MongoDB Data Import Tool" -ForegroundColor Green
Write-Host "Target: $ConnectionString" -ForegroundColor Cyan
Write-Host "Source: $ImportDirectory" -ForegroundColor Cyan

if (-not (Test-Path $ImportDirectory)) {
    Write-Host "❌ Import directory not found: $ImportDirectory" -ForegroundColor Red
    exit 1
}

# Check if mongoimport and mongorestore are available
$hasMongoImport = Get-Command "mongoimport" -ErrorAction SilentlyContinue
$hasMongoRestore = Get-Command "mongorestore" -ErrorAction SilentlyContinue

if ($hasMongoRestore -and (Test-Path "$ImportDirectory/full-backup")) {
    Write-Host "🔄 Using mongorestore (recommended for full fidelity)..." -ForegroundColor Yellow
    
    if ($DropExisting) {
        Write-Host "⚠️  Dropping existing database..." -ForegroundColor Red
        mongorestore --uri="$ConnectionString" --drop --db="movie-ratings-db" "$ImportDirectory/full-backup/movie-ratings-db/"
    } else {
        mongorestore --uri="$ConnectionString" --db="movie-ratings-db" "$ImportDirectory/full-backup/movie-ratings-db/"
    }
    
} elseif ($hasMongoImport) {
    Write-Host "🔄 Using mongoimport for JSON files..." -ForegroundColor Yellow
    
    $jsonFiles = Get-ChildItem "$ImportDirectory/*.json" | Where-Object { $_.Name -ne "export_metadata.json" }
    
    foreach ($file in $jsonFiles) {
        $collection = $file.BaseName
        Write-Host "   Importing $collection..." -ForegroundColor White
        
        if ($DropExisting) {
            mongoimport --uri="$ConnectionString" --db="movie-ratings-db" --collection="$collection" --file="$($file.FullName)" --jsonArray --drop
        } else {
            mongoimport --uri="$ConnectionString" --db="movie-ratings-db" --collection="$collection" --file="$($file.FullName)" --jsonArray
        }
    }
    
} else {
    Write-Host "❌ MongoDB tools not found. Please install MongoDB Database Tools" -ForegroundColor Red
    Write-Host "💡 Alternative: Use the Python migrator script" -ForegroundColor Yellow
    Write-Host "   python mongodb_migrator.py import --target-uri '$ConnectionString' --database movie-ratings-db" -ForegroundColor Gray
}

Write-Host "✅ Import process completed!" -ForegroundColor Green
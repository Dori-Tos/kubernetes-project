# PowerShell Script to Add 'bald' Field to All Actors (Migration)
# This script demonstrates database schema evolution in MongoDB

Write-Host "=== Actor Migration: Adding 'bald' Field ===" -ForegroundColor Green

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

# Function to apply migration to a specific environment
function Apply-BaldMigration {
    param(
        [string]$Environment,
        [string]$Namespace,
        [string]$ServiceName,
        [string]$DatabaseName,
        [string]$Port
    )
    
    Write-Host "`n=== Applying Migration to $Environment Environment ===" -ForegroundColor Cyan
    
    # Setup port forwarding
    Write-Host "Setting up port forwarding to $Environment MongoDB..." -ForegroundColor Yellow
    $portForwardJob = Start-Job -ScriptBlock {
        param($ns, $svc, $port)
        kubectl port-forward -n $ns svc/$svc ${port}:27017
    } -ArgumentList $Namespace, $ServiceName, $Port
    
    # Wait for port forward to establish
    Start-Sleep -Seconds 5
    
    try {
        # Connection string
        $connectionString = "mongodb://app-user:appuser123@localhost:$Port/$DatabaseName?authSource=admin"
        
        # Check current state
        Write-Host "Checking current actors without 'bald' field..." -ForegroundColor Yellow
        $checkQuery = "db.actors.countDocuments({bald: {`$exists: false}})"
        $actorsWithoutBald = & $mongoCommand $connectionString --eval $checkQuery --quiet
        Write-Host "Found $actorsWithoutBald actors without 'bald' field" -ForegroundColor Cyan
        
        if ([int]$actorsWithoutBald -gt 0) {
            # Sample some actors before migration
            Write-Host "Sample actors before migration:" -ForegroundColor Yellow
            $sampleBefore = & $mongoCommand $connectionString --eval "db.actors.find({bald: {`$exists: false}}).limit(3).forEach(printjson)" --quiet
            Write-Host $sampleBefore
            
            # Apply migration with realistic bald data based on actor names
            Write-Host "Applying migration with realistic 'bald' values..." -ForegroundColor Cyan
            
            # Migration logic: Set bald=true for specific actors, false for others
            $migrationScript = @"
// Migration: Add 'bald' field to actors
var baldActors = ['Vin Diesel', 'Dwayne Johnson', 'Bruce Willis', 'Samuel L. Jackson', 'Patrick Stewart'];
var result1 = db.actors.updateMany(
    { 
        name: { `$in: baldActors },
        bald: { `$exists: false }
    },
    { `$set: { bald: true } }
);
print('Set bald=true for ' + result1.modifiedCount + ' actors');

var result2 = db.actors.updateMany(
    {
        name: { `$nin: baldActors },
        bald: { `$exists: false }
    },
    { `$set: { bald: false } }
);
print('Set bald=false for ' + result2.modifiedCount + ' actors');

print('Total migration completed: ' + (result1.modifiedCount + result2.modifiedCount) + ' actors updated');
"@
            
            # Execute migration
            $migrationResult = & $mongoCommand $connectionString --eval $migrationScript --quiet
            Write-Host $migrationResult -ForegroundColor Green
            
            # Verify migration
            Write-Host "Verifying migration..." -ForegroundColor Yellow
            $verifyQuery = "db.actors.countDocuments({bald: {`$exists: true}})"
            $actorsWithBald = & $mongoCommand $connectionString --eval $verifyQuery --quiet
            Write-Host "Verification: $actorsWithBald actors now have 'bald' field" -ForegroundColor Green
            
            # Show sample after migration
            Write-Host "Sample actors after migration:" -ForegroundColor Yellow
            $sampleAfter = & $mongoCommand $connectionString --eval "db.actors.find({}).limit(3).forEach(printjson)" --quiet
            Write-Host $sampleAfter
            
        } else {
            Write-Host "Migration already applied - no changes needed" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "Error during migration: $_" -ForegroundColor Red
        return $false
    } finally {
        # Clean up port forward
        Write-Host "Cleaning up port forwarding..." -ForegroundColor Yellow
        Stop-Job $portForwardJob -ErrorAction SilentlyContinue
        Remove-Job $portForwardJob -ErrorAction SilentlyContinue
    }
    
    return $true
}

# Apply migration to test environment first
Write-Host "=== Starting Database Migration Process ===" -ForegroundColor Blue
Write-Host "This migration adds a 'bald' boolean field to all actors" -ForegroundColor White

$testSuccess = Apply-BaldMigration -Environment "Test" -Namespace "default" -ServiceName "example-mongodb-svc" -DatabaseName "movie-ratings-db" -Port "27018"

if ($testSuccess) {
    Write-Host "`n=== Test Migration Successful! ===" -ForegroundColor Green
    
    # Ask for confirmation before production
    $confirmation = Read-Host "`nApply migration to PRODUCTION environment? (y/N)"
    
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y' -or $confirmation -eq 'yes') {
        $prodSuccess = Apply-BaldMigration -Environment "Production" -Namespace "production" -ServiceName "production-mongodb-svc" -DatabaseName "app-production" -Port "27017"
        
        if ($prodSuccess) {
            Write-Host "`n🎉 MIGRATION COMPLETED SUCCESSFULLY! 🎉" -ForegroundColor Green
            Write-Host "All actors now have a 'bald' boolean field in both environments" -ForegroundColor White
        } else {
            Write-Host "`n❌ Production migration failed!" -ForegroundColor Red
        }
    } else {
        Write-Host "`nProduction migration skipped by user choice." -ForegroundColor Yellow
    }
} else {
    Write-Host "`n❌ Test migration failed - production migration aborted!" -ForegroundColor Red
}

Write-Host "`n=== Migration Script Completed ===" -ForegroundColor Blue
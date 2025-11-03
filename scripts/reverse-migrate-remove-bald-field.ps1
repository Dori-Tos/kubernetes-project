# PowerShell script to reverse migrate: remove the 'bald' field from actors
# This script removes the 'bald' field added by the v1.0.35 migration
# Usage: Run this script to reverse the bald field migration

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("test", "production")]
    [string]$Environment = "test"
)

Write-Host "🔄 Starting reverse migration: removing 'bald' field from actors" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Set database and namespace based on environment
if ($Environment -eq "production") {
    $namespace = "production"
    $database = "app-production"
    Write-Host "⚠️  PRODUCTION ENVIRONMENT - Proceed with caution!" -ForegroundColor Red
} else {
    $namespace = "default"
    $database = "movie-ratings-db"
    Write-Host "✅ Test environment selected" -ForegroundColor Green
}

# Confirmation prompt for production
if ($Environment -eq "production") {
    $confirmation = Read-Host "Are you sure you want to reverse migrate in PRODUCTION? Type 'YES' to continue"
    if ($confirmation -ne "YES") {
        Write-Host "❌ Migration cancelled by user" -ForegroundColor Red
        exit 1
    }
}

try {
    Write-Host "📋 Checking MongoDB pod status..." -ForegroundColor Blue
    
    # Get MongoDB pod name
    $mongodbPod = kubectl get pods -n $namespace -l app=mongodb-shard -o jsonpath="{.items[0].metadata.name}" 2>$null
    
    if ([string]::IsNullOrEmpty($mongodbPod)) {
        Write-Host "❌ No MongoDB pod found in namespace '$namespace'" -ForegroundColor Red
        Write-Host "Available pods:" -ForegroundColor Yellow
        kubectl get pods -n $namespace
        exit 1
    }
    
    Write-Host "✅ Found MongoDB pod: $mongodbPod" -ForegroundColor Green
    
    # Check if pod is ready
    $podStatus = kubectl get pod $mongodbPod -n $namespace -o jsonpath="{.status.phase}"
    if ($podStatus -ne "Running") {
        Write-Host "❌ MongoDB pod is not running. Status: $podStatus" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "🔗 Setting up port forwarding..." -ForegroundColor Blue
    
    # Start port forwarding in background
    $portForwardJob = Start-Job -ScriptBlock {
        kubectl port-forward $args[0] 27017:27017 -n $args[1]
    } -ArgumentList $mongodbPod, $namespace
    
    # Wait a moment for port forwarding to establish
    Start-Sleep -Seconds 3
    
    # Check if port forwarding is working
    $portCheck = Test-NetConnection -ComputerName localhost -Port 27017 -WarningAction SilentlyContinue
    if (-not $portCheck.TcpTestSucceeded) {
        Write-Host "❌ Port forwarding failed to establish" -ForegroundColor Red
        Stop-Job $portForwardJob -Force
        Remove-Job $portForwardJob -Force
        exit 1
    }
    
    Write-Host "✅ Port forwarding established successfully" -ForegroundColor Green
    
    Write-Host "🗃️  Running reverse migration script..." -ForegroundColor Blue
    
    # Path to the migration script
    $migrationScript = Join-Path $PSScriptRoot "..\migrations\v1.0.36-remove-bald-field.js"
    
    if (-not (Test-Path $migrationScript)) {
        Write-Host "❌ Migration script not found: $migrationScript" -ForegroundColor Red
        Stop-Job $portForwardJob -Force
        Remove-Job $portForwardJob -Force
        exit 1
    }
    
    # Try mongosh first, fall back to mongo if not available
    $mongoCommand = "mongosh"
    $mongoVersion = & $mongoCommand --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  mongosh not found, trying legacy mongo client..." -ForegroundColor Yellow
        $mongoCommand = "mongo"
        $mongoVersion = & $mongoCommand --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Neither mongosh nor mongo client found" -ForegroundColor Red
            Stop-Job $portForwardJob -Force
            Remove-Job $portForwardJob -Force
            exit 1
        }
    }
    
    Write-Host "✅ Using MongoDB client: $mongoCommand" -ForegroundColor Green
    
    # Execute the reverse migration
    Write-Host "⏳ Executing reverse migration on database '$database'..." -ForegroundColor Yellow
    
    if ($mongoCommand -eq "mongosh") {
        & mongosh mongodb://localhost:27017/$database --file $migrationScript
    } else {
        & mongo mongodb://localhost:27017/$database $migrationScript
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Reverse migration completed successfully!" -ForegroundColor Green
        Write-Host "🎯 The 'bald' field has been removed from all actors" -ForegroundColor Green
    } else {
        Write-Host "❌ Reverse migration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        throw "Migration execution failed"
    }
    
} catch {
    Write-Host "❌ Error during reverse migration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up port forwarding
    if ($portForwardJob) {
        Write-Host "🧹 Cleaning up port forwarding..." -ForegroundColor Blue
        Stop-Job $portForwardJob -Force
        Remove-Job $portForwardJob -Force
        Write-Host "✅ Port forwarding stopped" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "🎉 Reverse migration process completed!" -ForegroundColor Green
Write-Host "✨ The 'bald' field has been removed from the actors collection" -ForegroundColor Cyan
Write-Host "🔄 The application UI will now hide bald-related elements" -ForegroundColor Cyan
# Simple Test Script for Bald Field Migration
Write-Host "=== Testing Bald Field Migration ===" -ForegroundColor Blue

# Check if migration files exist
$migrationScript = "migrations\v1.0.35-add-bald-field.js"
$powershellScript = "scripts\migrate-add-bald-field.ps1"

if (Test-Path $migrationScript) {
    Write-Host "✅ JavaScript migration file found: $migrationScript" -ForegroundColor Green
} else {
    Write-Host "❌ JavaScript migration file missing: $migrationScript" -ForegroundColor Red
}

if (Test-Path $powershellScript) {
    Write-Host "✅ PowerShell migration script found: $powershellScript" -ForegroundColor Green
} else {
    Write-Host "❌ PowerShell migration script missing: $powershellScript" -ForegroundColor Red
}

Write-Host "`n=== Migration Options ===" -ForegroundColor Yellow
Write-Host "Option 1 (Automated): Run .\scripts\migrate-add-bald-field.ps1" -ForegroundColor White
Write-Host "Option 2 (Manual): Use mongosh with migrations\v1.0.35-add-bald-field.js" -ForegroundColor White

Write-Host "`n=== Manual Command Examples ===" -ForegroundColor Yellow
Write-Host "Test Environment:" -ForegroundColor Cyan
Write-Host "  kubectl port-forward -n default svc/example-mongodb-svc 27018:27017" -ForegroundColor White
Write-Host "  mongosh 'mongodb://app-user:appuser123@localhost:27018/movie-ratings-db?authSource=admin' migrations\v1.0.35-add-bald-field.js" -ForegroundColor White

Write-Host "`nProduction Environment:" -ForegroundColor Cyan  
Write-Host "  kubectl port-forward -n production svc/production-mongodb-svc 27017:27017" -ForegroundColor White
Write-Host "  mongosh 'mongodb://app-user:appuser123@localhost:27017/app-production?authSource=admin' migrations\v1.0.35-add-bald-field.js" -ForegroundColor White

Write-Host "`n=== For Your Presentation ===" -ForegroundColor Green
Write-Host "This demonstrates:" -ForegroundColor White
Write-Host "• Schema evolution in MongoDB" -ForegroundColor White  
Write-Host "• Safe migration testing (test -> production)" -ForegroundColor White
Write-Host "• Data transformation during deployment" -ForegroundColor White
Write-Host "• Realistic migration scenarios" -ForegroundColor White
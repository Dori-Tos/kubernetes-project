# Database Migration: Add 'bald' Field to Actors

This migration demonstrates **schema evolution** in MongoDB by adding a new boolean field `bald` to all actor documents.

## 🎯 Purpose

Perfect example for your professor showing:
- **Database Migration** during application updates
- **Schema Evolution** in NoSQL databases  
- **Zero-downtime deployment** with rolling updates
- **Safe migration practices** (test → production)

## 📁 Files Created

### Migration Scripts
- **`migrations/v1.0.35-add-bald-field.js`** - Pure MongoDB JavaScript migration
- **`scripts/migrate-add-bald-field.ps1`** - Automated PowerShell script with safety checks
- **`scripts/test-bald-migration.ps1`** - Test and validation script

### Application Updates
- **Updated `app/templates/actors.html`** - Now displays bald status with visual indicators

## 🚀 How to Use

### Option 1: Automated Script (Recommended)
```powershell
# Run the comprehensive migration script
.\scripts\migrate-add-bald-field.ps1

# This will:
# 1. Test migration on test environment first
# 2. Show before/after samples
# 3. Ask for confirmation before production
# 4. Apply to production with verification
```

### Option 2: Manual Execution
```powershell
# Test Environment
kubectl port-forward -n default svc/example-mongodb-svc 27018:27017
mongosh "mongodb://app-user:appuser123@localhost:27018/movie-ratings-db?authSource=admin" migrations/v1.0.35-add-bald-field.js

# Production Environment  
kubectl port-forward -n production svc/production-mongodb-svc 27017:27017
mongosh "mongodb://app-user:appuser123@localhost:27017/app-production?authSource=admin" migrations/v1.0.35-add-bald-field.js
```

## 🎬 Migration Logic

The migration intelligently assigns `bald` values:

### Bald Actors (bald: true)
- Vin Diesel
- Dwayne Johnson  
- Bruce Willis
- Samuel L. Jackson
- Patrick Stewart
- Jason Statham

### Non-Bald Actors (bald: false)
- All other actors

## 📊 What It Does

### Before Migration
```json
{
  "_id": ObjectId("..."),
  "name": "Vin Diesel",
  "age": 56
}
```

### After Migration
```json
{
  "_id": ObjectId("..."),
  "name": "Vin Diesel", 
  "age": 56,
  "bald": true
}
```

## 🔍 Verification

The migration includes automatic verification:
- Counts actors before/after migration
- Shows sample documents
- Provides summary statistics
- Ensures no data loss

## 🎨 UI Updates

The actors page now shows:
- **🔶 Bald** - Orange badge for bald actors
- **🟢 Has Hair** - Green badge for non-bald actors

## 📝 For Your Presentation

This demonstrates to your professor:

### ✅ **Database Migration Requirements Met:**
1. **Schema Evolution** - Adding new fields to existing documents
2. **Data Transformation** - Intelligent value assignment based on business logic
3. **Zero Downtime** - MongoDB migrations don't lock the database
4. **Safe Practices** - Test environment first, verification steps

### ✅ **Rolling Update Integration:**
- Migration can be run as part of deployment process
- Application gracefully handles both old and new document formats
- UI updates deployed with same rolling update mechanism

### 🎯 **Perfect Presentation Flow:**
1. **Show current application** - Actors without bald field
2. **Run migration script** - Demonstrate the process
3. **Show updated application** - Actors now display bald status
4. **Explain benefits** - Schema flexibility, zero downtime, safe practices

This gives you a concrete example of "database migration during application updates" that your professor requested!
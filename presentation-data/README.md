# Presentation Data Scripts

This directory contains scripts and data files for adding sample data to your MongoDB databases for presentation purposes.

## 📁 Files Structure

### Data Files (presentation-data/)
- `actors-presentation.json` - 1 new actor (Zendaya, Timothée Chalamet)
- `movies-presentation.json` - 1 new movies (Dune)
- `reviews-presentation.json` - 6 new reviews from various users

### Scripts (scripts/)
- `add-presentation-data-test.ps1` - Add data to test environment (default namespace)
- `add-presentation-data-production.ps1` - Add data to production environment
- `remove-presentation-data-test.ps1` - Remove data from test environment

## 🚀 Usage Instructions

### Step 1: Test First (Recommended)
```powershell
# Navigate to project root
cd C:\Private\Folders\Ecam\5MIN\Distributed_Systems\Project\kubernetes-project

# Add test data to default namespace
.\scripts\add-presentation-data-test.ps1
```

### Step 2: Verify Test Data
- Check your test application at http://movierating.local
- Ensure the new movies, actors, and reviews appear correctly
- Test all pages (Movies, Actors, Reviews)

### Step 3: Add to Production
```powershell
# Once test is successful, add to production
.\scripts\add-presentation-data-production.ps1
```

### Step 4: Clean Up Test (Optional)
```powershell
# Remove test data after successful production deployment
.\scripts\remove-presentation-data-test.ps1
```
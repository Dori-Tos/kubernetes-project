// MongoDB Migration Script: Add 'bald' field to all actors
// Version: v1.0.35
// Description: Add boolean 'bald' field to actor documents

// Get the database (adjust database name as needed)
db = db.getSiblingDB('app-production'); // Change to 'movie-ratings-db' for test environment

print("=== Migration v1.0.35: Add 'bald' field to actors ===");

// Check current state
const actorsWithoutBald = db.actors.countDocuments({ bald: { $exists: false } });
print(`Found ${actorsWithoutBald} actors without 'bald' field`);

if (actorsWithoutBald > 0) {
    print("Sample actors before migration:");
    db.actors.find({ bald: { $exists: false } }).limit(2).forEach(printjson);
    
    // Migration: Add 'bald' field with realistic values
    // Known bald actors get true, others get false
    const baldActorNames = [
        'Vin Diesel', 
        'Dwayne Johnson', 
        'Bruce Willis', 
        'Samuel L. Jackson', 
        'Patrick Stewart',
        'Jason Statham'
    ];
    
    // Set bald=true for known bald actors
    const result1 = db.actors.updateMany(
        { 
            name: { $in: baldActorNames },
            bald: { $exists: false }
        },
        { $set: { bald: true } }
    );
    
    print(`Set bald=true for ${result1.modifiedCount} actors`);
    
    // Set bald=false for all other actors
    const result2 = db.actors.updateMany(
        {
            name: { $nin: baldActorNames },
            bald: { $exists: false }
        },
        { $set: { bald: false } }
    );
    
    print(`Set bald=false for ${result2.modifiedCount} actors`);
    
    // Verify migration
    const totalUpdated = result1.modifiedCount + result2.modifiedCount;
    print(`Migration completed: Updated ${totalUpdated} actors`);
    
    // Show sample of updated documents
    print("Sample actors after migration:");
    db.actors.find({}).limit(3).forEach(printjson);
    
    // Summary statistics
    const baldCount = db.actors.countDocuments({ bald: true });
    const notBaldCount = db.actors.countDocuments({ bald: false });
    print(`Summary: ${baldCount} bald actors, ${notBaldCount} non-bald actors`);
    
} else {
    print("Migration already applied - no changes needed");
}

print("=== Migration v1.0.35 completed ===");
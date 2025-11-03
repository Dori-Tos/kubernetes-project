// Migration script to remove the 'bald' field from all actors
// Version: v1.0.36-remove-bald-field
// Purpose: Reverse the v1.0.35-add-bald-field migration
// Usage: Run this script in MongoDB to remove the 'bald' field from all actors

// Connect to the database
// This script should be run in the context of the movie database

print("Starting reverse migration: removing 'bald' field from actors collection...");

try {
    // Get reference to the actors collection
    const actorsCollection = db.actors;
    
    // Count documents that have the bald field before removal
    const countWithBald = actorsCollection.countDocuments({ "bald": { "$exists": true } });
    print(`Found ${countWithBald} actors with 'bald' field`);
    
    if (countWithBald === 0) {
        print("No actors found with 'bald' field. Migration may have already been reversed or never applied.");
    } else {
        // Remove the 'bald' field from all documents that have it
        const result = actorsCollection.updateMany(
            { "bald": { "$exists": true } },  // Only update documents that have the bald field
            { "$unset": { "bald": "" } }       // Remove the bald field
        );
        
        print(`Reverse migration completed successfully!`);
        print(`Modified ${result.modifiedCount} actors`);
        print(`Matched ${result.matchedCount} actors with 'bald' field`);
    }
    
    // Verify the field has been removed
    const remainingCount = actorsCollection.countDocuments({ "bald": { "$exists": true } });
    print(`Actors still with 'bald' field after removal: ${remainingCount}`);
    
    if (remainingCount === 0) {
        print("✅ Reverse migration verification successful: all 'bald' fields removed");
    } else {
        print("⚠️ Warning: Some actors still have the 'bald' field");
    }
    
} catch (error) {
    print("❌ Error during reverse migration:");
    print(error.toString());
    throw error;
}

print("Reverse migration script completed.");
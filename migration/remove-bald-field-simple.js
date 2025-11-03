// Simple migration script to REMOVE the 'bald' field from actors
// Use this for live demo to show migration rollback

print("=== REMOVING 'bald' field from actors ===");

try {
    // Check current state
    var countWithBald = db.actors.countDocuments({bald: {$exists: true}});
    print("Actors with 'bald' field before removal: " + countWithBald);
    
    if (countWithBald > 0) {
        // Show sample before removal
        print("\n=== Sample actors BEFORE removal ===");
        db.actors.find({bald: {$exists: true}}).limit(2).forEach(function(actor) {
            print(actor.name + " - bald: " + actor.bald);
        });
        
        // Remove the 'bald' field from all actors
        var result = db.actors.updateMany(
            { bald: { $exists: true } },  // Find all actors with bald field
            { $unset: { bald: "" } }       // Remove the bald field
        );
        
        print("\n✅ Migration rollback completed!");
        print("Removed 'bald' field from " + result.modifiedCount + " actors");
        
        // Verify removal
        var remainingCount = db.actors.countDocuments({bald: {$exists: true}});
        print("Actors still with 'bald' field: " + remainingCount);
        
        if (remainingCount === 0) {
            print("🎉 SUCCESS: All 'bald' fields removed!");
        } else {
            print("⚠️ Warning: Some actors still have the 'bald' field");
        }
        
    } else {
        print("✅ No 'bald' fields found - migration already removed or never applied");
    }
    
    // Show final state
    print("\n=== Final verification ===");
    var totalActors = db.actors.countDocuments({});
    var actorsWithBald = db.actors.countDocuments({bald: {$exists: true}});
    
    print("Total actors: " + totalActors);
    print("Actors with 'bald' field: " + actorsWithBald);
    
} catch (error) {
    print("❌ Error during rollback: " + error.toString());
}

print("\n=== Migration rollback completed ===");
// Simple migration script to add 'bald' field to actors
// Run this script directly in mongosh

print("=== Adding 'bald' field to actors ===");

// Check current state
var countWithoutBald = db.actors.countDocuments({bald: {$exists: false}});
print("Actors without 'bald' field: " + countWithoutBald);

if (countWithoutBald > 0) {
    // Define actors who are bald
    var baldActors = ['Bruce Willis'];
    
    // Set bald=true for known bald actors
    var result1 = db.actors.updateMany(
        { 
            name: { $in: baldActors },
            bald: { $exists: false }
        },
        { $set: { bald: true } }
    );
    print("Set bald=true for " + result1.modifiedCount + " actors");
    
    // Set bald=false for all other actors
    var result2 = db.actors.updateMany(
        {
            name: { $nin: baldActors },
            bald: { $exists: false }
        },
        { $set: { bald: false } }
    );
    print("Set bald=false for " + result2.modifiedCount + " actors");
    
    print("✅ Migration completed: " + (result1.modifiedCount + result2.modifiedCount) + " actors updated");
} else {
    print("✅ Migration already applied - all actors have 'bald' field");
}

// Verify results
var totalWithBald = db.actors.countDocuments({bald: {$exists: true}});
var baldCount = db.actors.countDocuments({bald: true});
var notBaldCount = db.actors.countDocuments({bald: false});

print("=== Migration Summary ===");
print("Total actors with 'bald' field: " + totalWithBald);
print("Bald actors: " + baldCount);
print("Not bald actors: " + notBaldCount);
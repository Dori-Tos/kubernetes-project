# PowerShell script to migrate ratings to reviews and rename all references
$mongoScript = @"
// Step 1: Copy all data from 'ratings' to 'reviews'
print('📋 Step 1: Migrating data from ratings to reviews...');
db.reviews.deleteMany({});

const ratingsData = db.ratings.find({}).toArray();
print('Found ' + ratingsData.length + ' documents in ratings collection');

if (ratingsData.length > 0) {
  const reviewsResult = db.reviews.insertMany(ratingsData);
  print('✅ Copied ' + reviewsResult.insertedIds.length + ' documents to reviews collection');
} else {
  print('⚠️  No data found in ratings collection');
}

// Step 2: Update movies collection - rename rating_ids to review_ids (if they exist)
print('');
print('📋 Step 2: Updating movies collection...');

const moviesUpdateResult = db.movies.updateMany(
  {rating_ids: {`$exists: true}},
  {`$rename: {rating_ids: 'review_ids'}}
);
print('✅ Updated ' + moviesUpdateResult.modifiedCount + ' movies - renamed rating_ids to review_ids');

// Step 3: Verify the migration
print('');
print('📊 Step 3: Verifying migration...');

const reviewsCount = db.reviews.countDocuments({});
const ratingsCount = db.ratings.countDocuments({});
const moviesCount = db.movies.countDocuments({});
const actorsCount = db.actors.countDocuments({});

print('✅ Reviews collection: ' + reviewsCount + ' documents');
print('📋 Ratings collection: ' + ratingsCount + ' documents (will be removed)');
print('🎬 Movies collection: ' + moviesCount + ' documents');
print('🎭 Actors collection: ' + actorsCount + ' documents');

// Step 4: Drop the old ratings collection
print('');
print('🗑️ Step 4: Removing old ratings collection...');
db.ratings.drop();
print('✅ Successfully dropped ratings collection');

// Step 5: Verify final state
print('');
print('🎉 Migration Complete! Final verification:');
const collections = db.runCommand('listCollections').cursor.firstBatch.map(c => c.name);
print('📚 Available collections: ' + collections.join(', '));

// Show sample data
const sampleReview = db.reviews.findOne();
if (sampleReview) {
  print('📝 Sample review: ' + JSON.stringify(sampleReview, null, 2));
}

print('');
print('✨ Data migration completed successfully!');
"@

# Execute the MongoDB script via kubectl on the primary node
Write-Host "🔄 Starting migration from ratings to reviews..."
kubectl exec -i example-mongodb-2 -n test -- mongosh "mongodb://app-user:appuser123@example-mongodb-svc:27017/movie-ratings-db?authSource=admin" --eval $mongoScript
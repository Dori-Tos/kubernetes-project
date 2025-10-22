# PowerShell script to create structured movie data in MongoDB
$mongoScript = @"
// Clear existing collections
db.actors.deleteMany({});
db.movies.deleteMany({});
db.reviews.deleteMany({});

print('🗑️ Cleared existing collections');

// Create Actors (id, name, age)
const actors = [
  {name: 'Leonardo DiCaprio', age: 49},
  {name: 'Marion Cotillard', age: 48}, 
  {name: 'Tom Hardy', age: 46},
  {name: 'Robert Downey Jr.', age: 58},
  {name: 'Chris Evans', age: 42},
  {name: 'Scarlett Johansson', age: 39},
  {name: 'Margot Robbie', age: 33},
  {name: 'Ryan Gosling', age: 43}
];

const actorResults = db.actors.insertMany(actors);
print('✅ Added ' + actors.length + ' actors');

// Create a map of actor names to IDs for reference
const actorMap = {};
db.actors.find({}).forEach(function(actor) {
  actorMap[actor.name] = actor._id;
});

// Create Movies (id, name, date, actor_ids[])
const movies = [
  {
    name: 'Inception',
    date: '2010-07-16',
    actor_ids: [
      actorMap['Leonardo DiCaprio'],
      actorMap['Marion Cotillard'],
      actorMap['Tom Hardy']
    ]
  },
  {
    name: 'Avengers: Endgame',
    date: '2019-04-26', 
    actor_ids: [
      actorMap['Robert Downey Jr.'],
      actorMap['Chris Evans'],
      actorMap['Scarlett Johansson']
    ]
  },
  {
    name: 'Barbie',
    date: '2023-07-21',
    actor_ids: [
      actorMap['Margot Robbie'],
      actorMap['Ryan Gosling']
    ]
  },
  {
    name: 'The Dark Knight Rises',
    date: '2012-07-20',
    actor_ids: [
      actorMap['Tom Hardy']
    ]
  }
];

const movieResults = db.movies.insertMany(movies);
print('✅ Added ' + movies.length + ' movies');

// Create a map of movie names to IDs for reference
const movieMap = {};
db.movies.find({}).forEach(function(movie) {
  movieMap[movie.name] = movie._id;
});

// Create Reviews (id, username, text, value, movie_id)
const reviews = [
  {
    username: 'john_doe',
    text: 'Mind-bending masterpiece! Amazing cinematography.',
    value: 5,
    movie_id: movieMap['Inception']
  },
  {
    username: 'movie_lover', 
    text: 'Great concept but a bit confusing at times.',
    value: 4,
    movie_id: movieMap['Inception']
  },
  {
    username: 'marvel_fan',
    text: 'Perfect ending to the MCU saga. Emotional and epic!',
    value: 5,
    movie_id: movieMap['Avengers: Endgame']
  },
  {
    username: 'critic123',
    text: 'Good action but too long. Could have been shorter.',
    value: 3,
    movie_id: movieMap['Avengers: Endgame']
  },
  {
    username: 'pink_fan',
    text: 'Fun and colorful! Great performances by Margot and Ryan.',
    value: 4,
    movie_id: movieMap['Barbie']
  },
  {
    username: 'batman_lover',
    text: 'Tom Hardy was intimidating as Bane and well-acted.',
    value: 4,
    movie_id: movieMap['The Dark Knight Rises']
  },
  {
    username: 'cinema_critic',
    text: 'Decent conclusion but not as good as Dark Knight.',
    value: 3,
    movie_id: movieMap['The Dark Knight Rises']
  }
];

const reviewResults = db.reviews.insertMany(reviews);
print('✅ Added ' + reviews.length + ' reviews');

print('🎉 Structured movie review data created successfully!');
print('📋 Collections: actors, movies, reviews');
print('🔗 Data properly linked with ObjectId references');

// Show summary
print('');
print('📊 Data Summary:');
print('Actors: ' + db.actors.countDocuments());
print('Movies: ' + db.movies.countDocuments());
print('Reviews: ' + db.reviews.countDocuments());
"@

# Execute the MongoDB script via kubectl on the primary node
Write-Host "Creating structured movie data in MongoDB..."
kubectl exec -i example-mongodb-2 -n test -- mongosh "mongodb://app-user:appuser123@example-mongodb-svc:27017/movie-ratings-db?authSource=admin" --eval $mongoScript
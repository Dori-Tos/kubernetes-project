# Connect to MongoDB and explore your data
kubectl exec -it example-mongodb-0 -n test -- mongosh "mongodb://app-user:appuser123@example-mongodb-svc:27017/movie-ratings-db?authSource=admin"

# Once connected, you can:
show dbs
use movie-ratings-db
show collections
db.movies.find().pretty()
db.actors.find().pretty()
db.ratings.find().pretty()
# Create a backup of your MongoDB data
kubectl exec -it example-mongodb-0 -n test -- mongodump --uri="mongodb://app-user:appuser123@example-mongodb-svc:27017/movie-ratings-db?authSource=admin" --out /tmp/backup

# Copy backup to your local machine
kubectl cp test/example-mongodb-0:/tmp/backup ./mongodb-backup
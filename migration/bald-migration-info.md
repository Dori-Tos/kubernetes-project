To apply the data mrigration:

mongosh "mongodb://app-user:appuser123@localhost:27018/app-production?authSource=admin" --file="migration/add-bald-field-simple.js"

To rollback:

mongosh "mongodb://app-user:appuser123@localhost:27018/app-production?authSource=admin" --file="migration/remove-bald-field-simple.js"
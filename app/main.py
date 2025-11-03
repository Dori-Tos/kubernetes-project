from flask import Flask, jsonify, render_template
import datetime
import os
import json
import logging
from datetime import datetime

# Environment configuration
ENVIRONMENT = os.getenv('ENVIRONMENT', 'default')
MONGODB_RESOURCE_NAME = os.getenv('MONGODB_RESOURCE_NAME', 
    'production-mongodb' if ENVIRONMENT == 'production' else 'example-mongodb')
NAMESPACE = os.getenv('NAMESPACE', 
    'production' if ENVIRONMENT == 'production' else 'default')

logging.info(f"Running in environment: {ENVIRONMENT}")
logging.info(f"MongoDB resource name: {MONGODB_RESOURCE_NAME}")
logging.info(f"Namespace: {NAMESPACE}")

# Try to import MongoDB dependencies, gracefully handle if not available (for testing)
try:
    from pymongo import MongoClient
    from bson.objectid import ObjectId
    MONGODB_AVAILABLE = True
except ImportError:
    # Create mock classes for testing environments
    class MongoClient:
        def __init__(self, *args, **kwargs):
            pass
        def __getitem__(self, key):
            return None
        def close(self):
            pass
        @property
        def admin(self):
            return MockAdmin()
    
    class MockAdmin:
        def command(self, cmd):
            return {"ok": 1}
    
    class ObjectId:
        def __init__(self, *args, **kwargs):
            pass
    MONGODB_AVAILABLE = False

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Helper function to convert ObjectId to string for JSON serialization
def convert_objectid(obj):
    """Convert ObjectId objects to strings for JSON serialization"""
    if MONGODB_AVAILABLE and isinstance(obj, ObjectId):
        return str(obj)
    elif isinstance(obj, dict):
        return {key: convert_objectid(value) for key, value in obj.items()}
    elif isinstance(obj, list):
        return [convert_objectid(item) for item in obj]
    else:
        return obj

# MongoDB connection
def get_db_connection():
    try:
        # Use the new auto-generated connection string from MongoDB operator
        mongodb_uri = os.getenv('MONGODB_CONNECTION_STRING')
        logging.info(f"MONGODB_CONNECTION_STRING: {mongodb_uri}")
        
        # Fallback to old MONGODB_URI for backward compatibility
        if not mongodb_uri:
            mongodb_uri = os.getenv('MONGODB_URI')
            logging.info(f"Falling back to MONGODB_URI: {mongodb_uri}")
            
        if not mongodb_uri:
            raise ValueError("Neither MONGODB_CONNECTION_STRING nor MONGODB_URI environment variable is set")
        
        logging.info(f"Attempting to connect to MongoDB with URI: {mongodb_uri}")
        client = MongoClient(mongodb_uri)
        # Test connection
        client.admin.command('ping')
        logging.info("Successfully connected to MongoDB")
        
        # Use the application database name
        db_name = os.getenv('MONGODB_DATABASE', 'movie-ratings-db')
        logging.info(f"Using database: {db_name}")
        return client[db_name]
    except Exception as e:
        logging.error(f"Failed to connect to MongoDB: {e}")
        return None

# Initialize database connection
db = get_db_connection()

@app.route('/')
def home():
    """Main page showing list of movies"""
    try:
        if db is None:
            return jsonify({"error": "Database connection failed"}), 500
        
        # Get all movies with their actors
        movies_raw = list(db.movies.find().sort("name", 1))
        movies = convert_objectid(movies_raw)
        
        # Enrich movies with actor details
        for movie in movies:
            if 'actor_ids' in movie:
                actor_details = []
                for actor_id in movie['actor_ids']:
                    actor = db.actors.find_one({"_id": ObjectId(actor_id)})
                    if actor:
                        actor_details.append(convert_objectid(actor))
                movie['actors'] = actor_details
            
            # Get average review rating
            reviews = list(db.reviews.find({"movie_id": ObjectId(movie['_id'])}))
            if reviews:
                avg_rating = sum(r['value'] for r in reviews) / len(reviews)
                movie['avg_rating'] = round(avg_rating, 1)
                movie['review_count'] = len(reviews)
            else:
                movie['avg_rating'] = 0
                movie['review_count'] = 0
        
        return render_template('movies.html', movies=movies, environment=ENVIRONMENT)
    except Exception as e:
        logging.error(f"Error in home route: {e}")
        return jsonify({"error": str(e)}), 500    

@app.route("/actors")
def actors():
    """Page showing list of all actors"""
    try:
        if db is None:
            return jsonify({"error": "Database connection failed"}), 500
        
        actors_raw = list(db.actors.find().sort("name", 1))
        actors = convert_objectid(actors_raw)
        
        # Add movie count for each actor
        for actor in actors:
            movie_count = db.movies.count_documents({"actor_ids": ObjectId(actor['_id'])})
            actor['movie_count'] = movie_count
        
        # Check if any actor has the 'bald' field (to conditionally show UI)
        has_bald_field = db.actors.count_documents({"bald": {"$exists": True}}) > 0
        
        return render_template('actors.html', actors=actors, environment=ENVIRONMENT, has_bald_field=has_bald_field)
    except Exception as e:
        logging.error(f"Error in actors route: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/reviews")
def reviews():
    """Page showing list of all reviews"""
    try:
        if db is None:
            return jsonify({"error": "Database connection failed"}), 500

        reviews_raw = list(db.reviews.find().sort("value", -1))
        reviews = convert_objectid(reviews_raw)

        # Enrich reviews with movie details
        for review in reviews:
            if 'movie_id' in review:
                movie = db.movies.find_one({"_id": ObjectId(review['movie_id'])})
                if movie:
                    review['movie'] = convert_objectid(movie)

        return render_template('reviews.html', reviews=reviews, environment=ENVIRONMENT)
    except Exception as e:
        logging.error(f"Error in reviews route: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/health")
def health():
    """Health dashboard page"""
    try:
        status = {"timestamp": datetime.now().isoformat()}
        
        if db is None:
            status["database"] = {"status": "disconnected", "error": "Database connection failed"}
            status["overall"] = "unhealthy"
        else:
            # Check database connection
            try:
                db.client.admin.command('ping')
                status["database"] = {"status": "connected"}
                
                # Get collection stats
                stats = {}
                collections = ['actors', 'movies', 'reviews']
                for collection_name in collections:
                    try:
                        count = db[collection_name].count_documents({})
                        stats[collection_name] = {"count": count, "status": "ok"}
                    except Exception as e:
                        stats[collection_name] = {"count": 0, "status": "error", "error": str(e)}
                
                status["collections"] = stats
                status["overall"] = "healthy"
                
            except Exception as e:
                status["database"] = {"status": "error", "error": str(e)}
                status["overall"] = "unhealthy"
        
        return render_template('health.html', status=status, environment=ENVIRONMENT)
    except Exception as e:
        logging.error(f"Error in health route: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/scale", methods=["POST"])
def scale_database():
    """Scale MongoDB replica set members"""
    try:
        from kubernetes import client, config
        from flask import request
        
        # Load Kubernetes configuration (in-cluster config)
        try:
            config.load_incluster_config()
        except Exception:
            # Fallback to local config for development
            config.load_kube_config()
        
        # Get the desired number of replicas from the request
        data = request.get_json()
        if not data or 'replicas' not in data:
            return jsonify({"error": "Missing 'replicas' parameter"}), 400
        
        replicas = data['replicas']
        
        # Validate replicas count (MongoDB best practices: odd numbers, 3-7 members)
        if not isinstance(replicas, int) or replicas < 1 or replicas > 7:
            return jsonify({"error": "Replicas must be between 1 and 7"}), 400
        
        if replicas % 2 == 0:
            return jsonify({"error": "MongoDB replica sets should have an odd number of members"}), 400
        
        logging.info(f"Scaling MongoDB to {replicas} replicas")
        
        # Create Kubernetes API client for custom resources
        api_client = client.ApiClient()
        custom_api = client.CustomObjectsApi(api_client)
        
        # Get current MongoDB configuration
        try:
            mongo_resource = custom_api.get_namespaced_custom_object(
                group="mongodbcommunity.mongodb.com",
                version="v1",
                namespace=NAMESPACE,
                plural="mongodbcommunity",
                name=MONGODB_RESOURCE_NAME
            )
        except Exception as e:
            logging.error(f"Failed to get MongoDB config: {e}")
            return jsonify({"error": "Failed to get current MongoDB configuration"}), 500
        
        current_replicas = mongo_resource.get('spec', {}).get('members', 3)
        
        if current_replicas == replicas:
            return jsonify({"message": f"MongoDB already has {replicas} replicas"}), 200
        
        # Update the members count
        patch_body = {"spec": {"members": replicas}}
        
        # Apply the updated configuration
        try:
            custom_api.patch_namespaced_custom_object(
                group="mongodbcommunity.mongodb.com",
                version="v1",
                namespace=NAMESPACE,
                plural="mongodbcommunity",
                name=MONGODB_RESOURCE_NAME,
                body=patch_body
            )
        except Exception as e:
            logging.error(f"Failed to scale MongoDB: {e}")
            return jsonify({"error": f"Failed to scale MongoDB: {str(e)}"}), 500
        
        logging.info(f"Successfully initiated scaling from {current_replicas} to {replicas} replicas")
        return jsonify({
            "message": f"MongoDB scaling initiated from {current_replicas} to {replicas} replicas",
            "previous_replicas": current_replicas,
            "target_replicas": replicas,
            "status": "scaling_in_progress"
        }), 200
        
    except Exception as e:
        logging.error(f"Error in scale route: {e}")
        return jsonify({"error": str(e)}), 500

@app.route("/get-replica-status")
def get_replica_status():
    """Get current MongoDB replica set status"""
    try:
        from kubernetes import client, config
        
        # Load Kubernetes configuration (in-cluster config)
        try:
            config.load_incluster_config()
        except Exception:
            # Fallback to local config for development
            config.load_kube_config()
        
        # Create Kubernetes API clients
        api_client = client.ApiClient()
        custom_api = client.CustomObjectsApi(api_client)
        core_api = client.CoreV1Api(api_client)
        
        # Get MongoDB configuration
        try:
            mongo_config = custom_api.get_namespaced_custom_object(
                group="mongodbcommunity.mongodb.com",
                version="v1",
                namespace=NAMESPACE,
                plural="mongodbcommunity",
                name=MONGODB_RESOURCE_NAME
            )
        except Exception as e:
            logging.error(f"Failed to get MongoDB config: {e}")
            return jsonify({"error": "Failed to get MongoDB configuration"}), 500
        
        spec_members = mongo_config.get('spec', {}).get('members', 0)
        status = mongo_config.get('status', {})
        current_members = status.get('currentMongoDBMembers', 0)
        current_replicas = status.get('currentStatefulSetReplicas', 0)
        phase = status.get('phase', 'Unknown')
        
        # Get pod status with multiple approaches for better coverage
        pod_info = []
        try:
            # Try multiple label selectors to ensure we get all pods
            selectors = [
                f"app={MONGODB_RESOURCE_NAME}-svc",
                "app.kubernetes.io/name=mongodb",
                f"app.kubernetes.io/instance={MONGODB_RESOURCE_NAME}"
            ]
            
            all_pods = {}  # Use dict to avoid duplicates
            
            for selector in selectors:
                try:
                    pods = core_api.list_namespaced_pod(
                        namespace=NAMESPACE,
                        label_selector=selector
                    )
                    
                    for pod in pods.items:
                        pod_name = pod.metadata.name
                        if pod_name.startswith(f'{MONGODB_RESOURCE_NAME}-'):
                            all_pods[pod_name] = pod
                except Exception as selector_error:
                    logging.warning(f"Failed to get pods with selector {selector}: {selector_error}")
            
            # Also try getting pods by name pattern (fallback)
            if not all_pods:
                try:
                    all_pods_in_namespace = core_api.list_namespaced_pod(namespace=NAMESPACE)
                    for pod in all_pods_in_namespace.items:
                        pod_name = pod.metadata.name
                        if pod_name.startswith(f'{MONGODB_RESOURCE_NAME}-'):
                            all_pods[pod_name] = pod
                except Exception as fallback_error:
                    logging.warning(f"Fallback pod search failed: {fallback_error}")
            
            # Process all found pods
            for pod_name, pod in all_pods.items():
                pod_status = pod.status.phase if pod.status.phase else 'Unknown'
                pod_ready = 'Unknown'
                
                # Get ready condition
                if pod.status.conditions:
                    for condition in pod.status.conditions:
                        if condition.type == 'Ready':
                            pod_ready = condition.status
                            break
                
                # Get more detailed status for pending pods
                if pod_status == 'Pending' and pod.status.container_statuses:
                    for container_status in pod.status.container_statuses:
                        if container_status.state and container_status.state.waiting:
                            waiting_reason = container_status.state.waiting.reason
                            pod_status = f"Pending ({waiting_reason})"
                            break
                
                pod_info.append({
                    'name': pod_name,
                    'status': pod_status,
                    'ready': pod_ready
                })
                
            # Sort pods by name for consistent display
            pod_info.sort(key=lambda x: x['name'])
            
            logging.info(f"Found {len(pod_info)} MongoDB pods: {[p['name'] for p in pod_info]}")
            
        except Exception as e:
            logging.error(f"Failed to get pod status: {e}")
            # Create placeholder entries based on expected replica count
            for i in range(spec_members):
                pod_info.append({
                    'name': f'{MONGODB_RESOURCE_NAME}-{i}',
                    'status': 'Unknown',
                    'ready': 'Unknown'
                })
        
        return jsonify({
            "desired_members": spec_members,
            "current_mongodb_members": current_members,
            "current_replicas": current_replicas,
            "phase": phase,
            "is_scaling": spec_members != current_members,
            "pods": pod_info
        })
        
    except Exception as e:
        logging.error(f"Error getting replica status: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/preview-production-data')
def preview_production_data():
    """
    Preview what data would be pulled from production database.
    Shows available movies and their related data counts.
    """
    if ENVIRONMENT == 'production':
        return jsonify({"error": "Data preview not available in production environment"}), 403
    
    try:
        # Production MongoDB connection details
        prod_connection_string = "mongodb://app-user:appuser123@production-mongodb-svc.production.svc.cluster.local/app-production?authSource=admin"
        
        # Connect to production database
        logging.info("Connecting to production database for preview...")
        prod_client = MongoClient(prod_connection_string)
        prod_client.admin.command('ping')  # Test connection
        prod_db = prod_client["app-production"]
        
        # Get movies with their review counts
        movies = list(prod_db.movies.find().sort("name", 1))
        movies_preview = []
        
        for movie in movies:
            movie_id = movie['_id']  # Keep as ObjectId for queries
            
            # Count reviews for this movie (reviews reference movies by ObjectId)
            review_count = prod_db.reviews.count_documents({"movie_id": movie_id})
            
            # Count actors for this movie (based on actor_ids array)
            actor_count = 0
            if 'actor_ids' in movie and isinstance(movie['actor_ids'], list):
                actor_count = len(movie['actor_ids'])
            
            movies_preview.append({
                "id": str(movie_id),  # Convert to string for JSON
                "title": movie.get('name', movie.get('title', 'Unknown Title')),  # Use 'name' field as seen in data
                "year": movie.get('date', movie.get('year', 'Unknown')),  # Use 'date' field as seen in data
                "genre": movie.get('genre', 'Unknown'),
                "review_count": review_count,
                "actor_count": actor_count
            })
        
        # Get total counts
        total_stats = {
            "total_movies": len(movies),
            "total_reviews": prod_db.reviews.count_documents({}),
            "total_actors": prod_db.actors.count_documents({})
        }
        
        return jsonify({
            "movies": movies_preview,
            "stats": total_stats
        })
        
    except Exception as e:
        logging.error(f"Error previewing production data: {e}")
        return jsonify({"error": f"Failed to preview data: {str(e)}"}), 500

@app.route('/sync-production-data', methods=['POST'])
def sync_production_data():
    """
    Sync selected movies and related data from production database to test database.
    Anonymizes reviewer names in reviews.
    """
    if ENVIRONMENT == 'production':
        return jsonify({"error": "Data sync not available in production environment"}), 403
    
    try:
        # Get parameters from request
        from flask import request
        data = request.get_json() or {}
        movie_count = int(data.get('movie_count', 5))  # Default to 5 movies
        
        # Production MongoDB connection details
        prod_connection_string = "mongodb://app-user:appuser123@production-mongodb-svc.production.svc.cluster.local/app-production?authSource=admin"
        
        # Connect to production database
        logging.info("Connecting to production database...")
        prod_client = MongoClient(prod_connection_string)
        prod_db = prod_client["app-production"]
        
        # Connect to test database (current environment)
        test_db = get_db_connection()
        if test_db is None:
            return jsonify({"error": "Could not connect to test database"}), 500
        
        sync_results = {
            "movies": 0,
            "reviews": 0,
            "actors": 0,
            "anonymized_reviewers": 0
        }
        
        # 1. Get selected movies (sorted by name for consistency)
        logging.info(f"Selecting {movie_count} movies from production...")
        selected_movies = list(prod_db.movies.find().sort("name", 1).limit(movie_count))
        selected_movie_ids = [str(movie['_id']) for movie in selected_movies]
        
        if selected_movies:
            # Clear and insert movies
            test_db.movies.delete_many({})
            test_db.movies.insert_many(selected_movies)
            sync_results["movies"] = len(selected_movies)
        
        # 2. Get reviews for selected movies with anonymization
        logging.info("Syncing reviews for selected movies...")
        # Convert movie IDs to ObjectIds for the query (reviews reference movies by ObjectId)
        selected_movie_object_ids = []
        for movie in selected_movies:
            movie_id = movie['_id']
            if isinstance(movie_id, dict) and '$oid' in movie_id:
                selected_movie_object_ids.append(ObjectId(movie_id['$oid']))
            elif isinstance(movie_id, str):
                selected_movie_object_ids.append(ObjectId(movie_id))
            else:
                selected_movie_object_ids.append(movie_id)
        
        reviews = list(prod_db.reviews.find({"movie_id": {"$in": selected_movie_object_ids}}))
        
        if reviews:
            # Clear existing test reviews
            test_db.reviews.delete_many({})
            
            # Anonymize reviewer names
            anonymized_reviews = []
            reviewer_counter = 0
            reviewer_mapping = {}
            
            for review in reviews:
                anonymized_review = review.copy()
                
                # Anonymize reviewer fields (check the actual field name 'username')
                for field in ['username', 'reviewer', 'author', 'user', 'name']:
                    if field in review and review[field]:
                        original_name = review[field]
                        if original_name not in reviewer_mapping:
                            reviewer_mapping[original_name] = f"reviewer_{reviewer_counter}"
                            reviewer_counter += 1
                        anonymized_review[field] = reviewer_mapping[original_name]
                
                anonymized_reviews.append(anonymized_review)
            
            # Insert anonymized reviews
            if anonymized_reviews:
                test_db.reviews.insert_many(anonymized_reviews)
                sync_results["reviews"] = len(anonymized_reviews)
                sync_results["anonymized_reviewers"] = len(reviewer_mapping)
        
        # 3. Get actors related to selected movies
        logging.info("Syncing related actors...")
        related_actor_ids = set()
        
        # Extract actor IDs from movies (based on the actual data structure we saw)
        for movie in selected_movies:
            if 'actor_ids' in movie and isinstance(movie['actor_ids'], list):
                for actor_id in movie['actor_ids']:
                    # Handle both ObjectId format and string format
                    if isinstance(actor_id, dict) and '$oid' in actor_id:
                        related_actor_ids.add(ObjectId(actor_id['$oid']))
                    elif isinstance(actor_id, str):
                        try:
                            related_actor_ids.add(ObjectId(actor_id))
                        except:
                            pass
                    else:
                        related_actor_ids.add(actor_id)
        
        if related_actor_ids:
            related_actors = list(prod_db.actors.find({"_id": {"$in": list(related_actor_ids)}}))
            
            if related_actors:
                test_db.actors.delete_many({})
                test_db.actors.insert_many(related_actors)
                sync_results["actors"] = len(related_actors)
                logging.info(f"Synced {len(related_actors)} related actors")
            else:
                logging.warning("No related actors found despite having actor_ids in movies")
        else:
            logging.info("No actor_ids found in selected movies")
        
        logging.info(f"Data sync completed successfully: {sync_results}")
        return jsonify({
            "message": f"Successfully synced {movie_count} movies and all related data",
            "results": sync_results,
            "selected_movies": [{"title": m.get('name', m.get('title', 'Unknown')), "year": m.get('date', m.get('year', 'Unknown'))} for m in selected_movies],
            "anonymization_note": f"Anonymized {sync_results['anonymized_reviewers']} unique reviewer names",
            "relationship_details": {
                "actors_linked": f"Synced {sync_results['actors']} actors referenced by selected movies",
                "reviews_linked": f"Synced {sync_results['reviews']} reviews for selected movies"
            }
        })
        
    except Exception as e:
        logging.error(f"Error syncing production data: {e}")
        return jsonify({"error": f"Failed to sync data: {str(e)}"}), 500

@app.route("/settings")
def settings():
    """Settings and admin page"""
    try:
        # Get environment info
        env_info = {
            "environment": ENVIRONMENT,
            "mongodb_resource": MONGODB_RESOURCE_NAME,
            "namespace": NAMESPACE,
            "is_test_env": ENVIRONMENT != 'production'
        }
        
        # Get database connection status
        if db is not None:
            db_status = "Connected"
            
            # Get collection counts
            collections_info = {}
            try:
                for collection_name in db.list_collection_names():
                    collections_info[collection_name] = db[collection_name].count_documents({})
            except Exception as e:
                logging.error(f"Error getting collection info: {e}")
                collections_info = {}
        else:
            db_status = "Disconnected"
            collections_info = {}
        
        return render_template('settings.html', 
                             env_info=env_info, 
                             db_status=db_status,
                             collections_info=collections_info)
        
    except Exception as e:
        logging.error(f"Error in settings route: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
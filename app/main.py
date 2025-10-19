from flask import Flask, jsonify, render_template
import os
from pymongo import MongoClient
from bson import ObjectId
import json
import logging
from datetime import datetime

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# Helper function to convert ObjectId to string for JSON serialization
def convert_objectid(obj):
    """Convert ObjectId objects to strings for JSON serialization"""
    if isinstance(obj, ObjectId):
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
        
        return render_template('movies.html', movies=movies)
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
        
        return render_template('actors.html', actors=actors)
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

        return render_template('reviews.html', reviews=reviews)
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
        
        return render_template('health.html', status=status)
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
                namespace="test",
                plural="mongodbcommunity",
                name="example-mongodb"
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
                namespace="test",
                plural="mongodbcommunity",
                name="example-mongodb",
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
                namespace="test",
                plural="mongodbcommunity",
                name="example-mongodb"
            )
        except Exception as e:
            logging.error(f"Failed to get MongoDB config: {e}")
            return jsonify({"error": "Failed to get MongoDB configuration"}), 500
        
        spec_members = mongo_config.get('spec', {}).get('members', 0)
        status = mongo_config.get('status', {})
        current_members = status.get('currentMongoDBMembers', 0)
        current_replicas = status.get('currentStatefulSetReplicas', 0)
        phase = status.get('phase', 'Unknown')
        
        # Get pod status
        pod_info = []
        try:
            pods = core_api.list_namespaced_pod(
                namespace="test",
                label_selector="app=example-mongodb-svc"
            )
            
            for pod in pods.items:
                pod_name = pod.metadata.name
                pod_status = pod.status.phase
                pod_ready = 'Unknown'
                
                if pod.status.conditions:
                    for condition in pod.status.conditions:
                        if condition.type == 'Ready':
                            pod_ready = condition.status
                            break
                
                pod_info.append({
                    'name': pod_name,
                    'status': pod_status,
                    'ready': pod_ready
                })
        except Exception as e:
            logging.warning(f"Failed to get pod status: {e}")
        
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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
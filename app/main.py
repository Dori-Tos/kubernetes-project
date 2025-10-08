import flask
from pymongo import MongoClient
import os

app = flask.Flask(__name__)

# MongoDB connection
MONGO_HOST = os.getenv('MONGO_HOST', 'mongodb-service')
MONGO_PORT = int(os.getenv('MONGO_PORT', '27017'))

try:
    client = MongoClient(f'mongodb://{MONGO_HOST}:{MONGO_PORT}/')
    db = client['moviedb']
    print("Connected to MongoDB!")
except Exception as e:
    print(f"Failed to connect to MongoDB: {e}")
    client = None

@app.route("/")
def home():
    return "Hello, World! This is a DB Service for movies. I want to see this change made at 20:58 on 07/10/2025 - haha"

@app.route("/actors")
def actors():
    if client is None:
        return "Database connection failed", 500
    
    try:
        actors_collection = db['actors']
        actors_list = list(actors_collection.find({}, {'_id': 0}))
        if not actors_list:
            return "No actors found in database"
        return {"actors": actors_list}
    except Exception as e:
        return f"Error fetching actors: {str(e)}", 500

@app.route("/reviews")
def reviews():
    if client is None:
        return "Database connection failed", 500
    
    try:
        reviews_collection = db['reviews']
        reviews_list = list(reviews_collection.find({}, {'_id': 0}))
        if not reviews_list:
            return "No reviews found in database"
        return {"reviews": reviews_list}
    except Exception as e:
        return f"Error fetching reviews: {str(e)}", 500

@app.route("/health")
def health():
    if client is None:
        return "Database connection failed", 500
    try:
        # Test database connection
        client.admin.command('ping')
        return "Healthy - Database connected"
    except Exception as e:
        return f"Unhealthy - Database error: {str(e)}", 500

@app.route("/settings")
def settings():
    return "List of settings."

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
from flask import Flask, jsonify
import os
from pymongo import MongoClient
import json

app = Flask(__name__)

# Use environment variables from deployment
MONGO_HOST = os.getenv('MONGO_HOST', 'mongodb-service')
MONGO_PORT = os.getenv('MONGO_PORT', '27017')
MONGO_URI = f'mongodb://{MONGO_HOST}:{MONGO_PORT}/'

def get_db_connection():
    try:
        client = MongoClient(MONGO_URI)
        client.admin.command('ping')
        return client['test']
    except Exception as e:
        print(f"Database connection failed: {e}")
        return None

@app.route("/")
def home():
    try:
        db = get_db_connection()
        if db is None:
            return jsonify({"error": "Database connection failed"}), 500

        # Get all movies from the collection
        movies = list(db.movies.find())

        # Convert ObjectId to string for JSON serialization
        for movie in movies:
            movie['_id'] = str(movie['_id'])

        return jsonify({
            "movies": movies,
            "count": len(movies)
        })

    except Exception as e:
        return jsonify({"error": f"Failed to fetch movies: {str(e)}"}), 500

@app.route("/actors")
def actors():
    return "List of actors will be here."

@app.route("/reviews")
def reviews():
    return "List of reviews will be here."

@app.route("/settings")
def settings():
    return "List of settings."

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
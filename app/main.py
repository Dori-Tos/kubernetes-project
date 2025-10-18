from flask import Flask, jsonify, render_template, jsonify
import os
from pymongo import MongoClient
import json
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

# MongoDB connection
def get_db_connection():
    try:
        mongodb_uri = os.getenv('MONGODB_URI')
        if not mongodb_uri:
            raise ValueError("MONGODB_URI environment variable not set")
        
        client = MongoClient(mongodb_uri)
        # Test connection
        client.admin.command('ping')
        logging.info("Successfully connected to MongoDB")
        
        db_name = os.getenv('MONGODB_DATABASE', 'testdb')
        return client[db_name]
    except Exception as e:
        logging.error(f"Failed to connect to MongoDB: {e}")
        return None

# Initialize database connection
db = get_db_connection()

@app.route('/')
def home():
    try:
        if db is None:
            return jsonify({"error": "Database connection failed"}), 500
        
        # Get collection count and sample data
        collections = db.list_collection_names()
        data = {}
        
        for collection_name in collections:
            collection = db[collection_name]
            count = collection.count_documents({})
            sample = list(collection.find().limit(5))
            data[collection_name] = {
                "count": count,
                "sample": sample
            }
        
        return render_template('index.html', data=data, collections=collections)
    except Exception as e:
        logging.error(f"Error in index route: {e}")
        return jsonify({"error": str(e)}), 500    

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
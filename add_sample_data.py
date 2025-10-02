#!/usr/bin/env python3
"""Script to add sample data to MongoDB for testing"""

from pymongo import MongoClient

# Connect to MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['moviedb']

# Add sample actors
actors_collection = db['actors']
sample_actors = [
    {"name": "Leonardo DiCaprio", "age": 49, "nationality": "American"},
    {"name": "Scarlett Johansson", "age": 40, "nationality": "American"},
    {"name": "Robert Downey Jr.", "age": 59, "nationality": "American"}
]

actors_collection.delete_many({})  # Clear existing data
actors_collection.insert_many(sample_actors)
print(f"Added {len(sample_actors)} actors to the database")

# Add sample reviews
reviews_collection = db['reviews']
sample_reviews = [
    {"movie": "Inception", "rating": 5, "comment": "Mind-bending masterpiece!"},
    {"movie": "Avengers: Endgame", "rating": 4, "comment": "Epic conclusion to the saga"},
    {"movie": "Lost in Translation", "rating": 4, "comment": "Beautiful and contemplative"}
]

reviews_collection.delete_many({})  # Clear existing data
reviews_collection.insert_many(sample_reviews)
print(f"Added {len(sample_reviews)} reviews to the database")

print("Sample data added successfully!")
client.close()
import pytest
from app.main import app

@pytest.fixture
def client():
    with app.test_client() as client:
        yield client

def test_home_route(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Hello, World! This is a DB Service for movies." in response.data

def test_actors_route(client):
    response = client.get("/actors")
    assert response.status_code == 200
    assert b"List of actors will be here." in response.data

def test_reviews_route(client):
    response = client.get("/reviews")
    assert response.status_code == 200
    assert b"List of reviews will be here." in response.data

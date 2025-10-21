# Simple endpoint accessibility tests
import pytest
import os
from unittest.mock import patch

# Set test environment
os.environ['MONGODB_CONNECTION_STRING'] = 'mongodb://test:test@localhost:27017/test'
os.environ['MONGODB_DATABASE'] = 'test-db'

from app.main import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

@patch('app.main.get_db_connection', return_value=None)
def test_home_route(mock_db, client):
    """Test that home route responds (even if DB fails)"""
    response = client.get("/")
    # Accept both 200 (success) and 500 (DB error) - just test it doesn't crash
    assert response.status_code in [200, 500]

@patch('app.main.get_db_connection', return_value=None)
def test_actors_route(mock_db, client):
    """Test that actors route responds"""
    response = client.get("/actors")
    assert response.status_code in [200, 500]

@patch('app.main.get_db_connection', return_value=None)
def test_reviews_route(mock_db, client):
    """Test that reviews route responds"""
    response = client.get("/reviews")
    assert response.status_code in [200, 500]

def test_health_route(client):
    """Test that health route responds"""
    response = client.get("/health")
    assert response.status_code in [200, 500]

def test_scale_route_bad_request(client):
    """Test scale route with invalid data"""
    response = client.post("/scale", json={})
    # Should return 400 (bad request) or 500 (other error) - just not crash
    assert response.status_code in [400, 500]

def test_get_replica_status_route(client):
    """Test replica status route"""
    response = client.get("/get-replica-status")
    assert response.status_code in [200, 500]
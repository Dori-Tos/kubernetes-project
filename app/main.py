import flask

app = flask.Flask(__name__)

@app.route("/")
def home():
    return "Hello, World! This is a DB Service for movies. FluxCD is working I think But you need to disable the cache in the browser to see the changes."

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
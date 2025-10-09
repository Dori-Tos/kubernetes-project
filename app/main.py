import flask
import datetime

app = flask.Flask(__name__)

@app.route("/")
def home():
    return "Hello, World! Test at 13:33 on 09/10/2025"

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
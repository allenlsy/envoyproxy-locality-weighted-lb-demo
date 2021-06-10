from flask import Flask
import os
print(os.environ['HOME'])

app = Flask(__name__)

healthy = True

@app.route('/')
def hello():
    global healthy
    if healthy:
        return f"Hello from {os.environ['HOST']}!"
    else:
        return "Unhealthy", 503

@app.route('/healthy')
def healthy():
    global healthy
    healthy = True
    return "Set to healthy", 201

@app.route('/unhealthy')
def unhealthy():
    global healthy
    healthy = False
    return "Set to unhealthy", 201

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8000, debug=False)

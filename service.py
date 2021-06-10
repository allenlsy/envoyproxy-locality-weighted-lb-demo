from flask import Flask
import os
print(os.environ['HOME'])

app = Flask(__name__)

@app.route('/')
def hello():
    return f"Hello from {os.environ['HOST']}!"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8000, debug=False)

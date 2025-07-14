from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/place_objects', methods=['POST'])
def place_objects():
    data = request.json
    # Dummy placement logic
    placements = [
        {"x": 1, "y": 2, "type": "chair"},
        {"x": 3, "y": 4, "type": "table"}
    ]
    return jsonify({"placements": placements})

if __name__ == '__main__':
    app.run(port=5000) 
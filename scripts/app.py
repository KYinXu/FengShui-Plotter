import random
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
from feng_shui_optimizer import FengShuiOptimizer
from helpers import (
    is_position_valid,
    check_object_collision,
    add_occupied_positions,
    get_object_grid_dimensions
)

app = Flask(__name__)
CORS(app)

def generate_random_layout(grid_width: int, grid_height: int, objects_to_place: list) -> list:
    """Generate a truly random layout with collision checking."""
    placements = []
    occupied_positions = set()
    
    print(f"Generating random layout for {objects_to_place}")
    
    for obj_type in objects_to_place:
        max_attempts = 1000
        placed = False
        
        for attempt in range(max_attempts):
            # Generate random position
            x = random.randint(0, grid_width - 1)
            y = random.randint(0, grid_height - 1)
            
            # Check if position is valid and doesn't collide
            if (is_position_valid(x, y, obj_type, occupied_positions, grid_width, grid_height) and
                not check_object_collision(x, y, obj_type, occupied_positions)):
                
                placements.append({
                    'type': obj_type,
                    'x': x,
                    'y': y
                })
                
                # Update occupied positions
                add_occupied_positions(x, y, obj_type, occupied_positions)
                placed = True
                print(f"Placed {obj_type} at ({x}, {y}) on attempt {attempt + 1}")
                break
        
        if not placed:
            # Fallback: place at origin
            print(f"WARNING: Could not place {obj_type} after {max_attempts} attempts, placing at origin")
            placements.append({
                'type': obj_type,
                'x': 0,
                'y': 0
            })
            add_occupied_positions(0, 0, obj_type, occupied_positions)
    
    return placements

@app.route('/test', methods=['GET'])
def test():
    """Test endpoint to verify server is running."""
    return jsonify({
        'status': 'ok',
        'message': 'Feng Shui scoring server is running!',
        'endpoints': [
            'GET /test',
            'POST /calculate-live-score',
            'POST /random-auto-placer',
            'POST /feng-shui-optimizer'
        ]
    })

@app.route('/calculate-live-score', methods=['POST'])
def calculate_live_score():
    try:
        data = request.get_json()
        print(f"Received request: {data}")
        
        placements = data.get('placements', [])
        grid_width = data.get('grid_width', 144)
        grid_height = data.get('grid_height', 144)
        
        print(f"Processing {len(placements)} placements on {grid_width}x{grid_height} grid")
        
        # Create optimizer instance
        optimizer = FengShuiOptimizer(grid_width, grid_height)
        
        # Calculate score for the current layout
        score = optimizer._calculate_layout_score(placements)
        print(f"Calculated score: {score}")
        
        # Get detailed breakdown
        breakdown = {
            'bagua_scores': 0.0,
            'command_position': optimizer._calculate_command_position_score(placements),
            'chi_flow': optimizer._calculate_chi_flow_score(placements),
            'layout_bonus': len(placements) * 10.0,
            'wall_bonuses': 0.0,
            'feng_shui_penalties': optimizer._calculate_feng_shui_penalties(placements),
            'door_blocked': optimizer._check_door_blocked(placements),
            'furniture_overlap': optimizer._check_furniture_overlap(placements),
        }
        
        # Calculate bagua scores
        for placement in placements:
            bagua_score = optimizer._calculate_bagua_score(placement)
            weight = optimizer.config['furniture_preferences'].get(
                placement['type'], {}).get('weight', 1)
            normalized_weight = weight / 10.0
            breakdown['bagua_scores'] += bagua_score * normalized_weight
        
        # Calculate wall bonuses
        for placement in placements:
            if placement['type'] in ['door', 'window']:
                x, y = placement['x'], placement['y']
                if (x == 0 or x == grid_width - 1 or 
                    y == 0 or y == grid_height - 1):
                    breakdown['wall_bonuses'] += 15.0
        
        # Generate message based on score
        if score >= 80:
            message = "Excellent Feng Shui! 🎉"
        elif score >= 60:
            message = "Good Feng Shui! 👍"
        elif score >= 40:
            message = "Fair Feng Shui ⚖️"
        elif score >= 20:
            message = "Poor Feng Shui ⚠️"
        else:
            message = "Very Poor Feng Shui ❌"
        
        # Generate recommendations
        recommendations = []
        if breakdown['feng_shui_penalties'] < -100:
            recommendations.append("Address Feng Shui violations for better energy flow")
        if breakdown['door_blocked'] < 0:
            recommendations.append("Move furniture away from doors")
        if breakdown['furniture_overlap'] < 0:
            recommendations.append("Separate overlapping furniture")
        if breakdown['command_position'] < 10:
            recommendations.append("Ensure bed and desk face the door for command position")
        
        result = {
            'score': score,
            'breakdown': breakdown,
            'message': message,
            'recommendations': recommendations
        }
        
        print(f"Sending response: {result}")
        return jsonify(result)
        
    except Exception as e:
        print(f"Error in calculate_live_score: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({
            'error': str(e),
            'score': 0.0,
            'breakdown': {},
            'message': 'Error calculating score',
            'recommendations': ['Check the layout configuration']
        }), 500

@app.route('/random-auto-placer', methods=['POST'])
def random_auto_placer():
    """Generate truly random placements with collision checking."""
    try:
        data = request.get_json()
        grid_width = data.get('grid_width', 144)
        grid_height = data.get('grid_height', 144)
        objects_to_place = data.get('objects_to_place', ['bed', 'desk', 'door', 'window'])
        
        print(f"Generating random placements for {len(objects_to_place)} objects on {grid_width}x{grid_height} grid")
        
        # Generate random layout with collision checking
        placements = generate_random_layout(grid_width, grid_height, objects_to_place)
        
        # Calculate score for the random layout
        optimizer = FengShuiOptimizer(grid_width, grid_height)
        score = optimizer._calculate_layout_score(placements)
        
        print(f"Random layout generated. Score: {score}")
        print(f"Random placements: {placements}")
        
        return jsonify({
            'placements': placements,
            'score': score
        })
        
    except Exception as e:
        print(f"Error in random_auto_placer: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/feng-shui-optimizer', methods=['POST'])
def feng_shui_optimizer():
    """Feng Shui optimization endpoint for the optimize button."""
    try:
        data = request.get_json()
        grid_width = data.get('grid_width', 144)
        grid_height = data.get('grid_height', 144)
        objects_to_place = data.get('objects_to_place', ['bed', 'desk', 'door', 'window'])
        
        print(f"Optimizing layout for {len(objects_to_place)} objects on {grid_width}x{grid_height} grid")
        
        # Create optimizer and get optimized placements
        optimizer = FengShuiOptimizer(grid_width, grid_height)
        placements, score = optimizer.optimize_layout(objects_to_place)
        
        print(f"Optimization complete. Score: {score}")
        print(f"Optimized placements: {placements}")
        
        return jsonify({
            'placements': placements,
            'score': score
        })
        
    except Exception as e:
        print(f"Error in feng_shui_optimizer: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("Starting Feng Shui Scoring Server...")
    print("Server will be available at: http://localhost:5000")
    print("Test endpoint: http://localhost:5000/test")
    app.run(debug=True, port=5000, host='0.0.0.0') 
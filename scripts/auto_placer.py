from flask import Flask, request, jsonify
import random
import json
import os

app = Flask(__name__)

# Load object configurations from JSON file
def load_object_config():
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config', 'objects.json')
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
        return config
    except FileNotFoundError:
        # Fallback to hardcoded values if config file not found
        return {
            "objects": {
                "bed": {"width": 80, "height": 60, "icon": "bed", "type": "furniture"},
                "desk": {"width": 48, "height": 24, "icon": "desk", "type": "furniture"},
                "door": {"width": 30, "height": 0, "icon": "door_front_door", "type": "boundary"},
                "window": {"width": 24, "height": 0, "icon": "window", "type": "boundary"}
            },
            "grid_cell_size": 12,
            "units": "inches"
        }

# Load configuration
OBJECT_CONFIG = load_object_config()
OBJECT_DIMENSIONS = OBJECT_CONFIG["objects"]
GRID_CELL_SIZE = OBJECT_CONFIG["grid_cell_size"]

def get_object_polygon(obj_type, x, y):
    """Get the polygon points for an object at position (x, y)"""
    if obj_type not in OBJECT_DIMENSIONS:
        return [(x, y), (x+1, y), (x+1, y+1), (x, y+1)]  # Default 1x1
    
    dims = OBJECT_DIMENSIONS[obj_type]
    width = dims['width']
    height = dims['height']
    
    # Convert inches to grid cells
    grid_width = max(1, width // GRID_CELL_SIZE)
    grid_height = max(1, height // GRID_CELL_SIZE)
    
    return [
        (x, y),
        (x + grid_width, y),
        (x + grid_width, y + grid_height),
        (x, y + grid_height)
    ]

def polygons_intersect(poly1, poly2):
    """Check if two polygons intersect"""
    # Simple bounding box intersection check
    min_x1, max_x1 = min(p[0] for p in poly1), max(p[0] for p in poly1)
    min_y1, max_y1 = min(p[1] for p in poly1), max(p[1] for p in poly1)
    min_x2, max_x2 = min(p[0] for p in poly2), max(p[0] for p in poly2)
    min_y2, max_y2 = min(p[1] for p in poly2), max(p[1] for p in poly2)
    
    return not (max_x1 < min_x2 or max_x2 < min_x1 or max_y1 < min_y2 or max_y2 < min_y1)

def is_position_valid(x, y, obj_type, occupied_positions, grid_width, grid_height):
    """Check if a position is valid for placing an object"""
    if obj_type not in OBJECT_DIMENSIONS:
        return False
    
    dims = OBJECT_DIMENSIONS[obj_type]
    width = dims['width']
    height = dims['height']
    
    # Convert inches to grid cells
    grid_obj_width = max(1, width // GRID_CELL_SIZE)
    grid_obj_height = max(1, height // GRID_CELL_SIZE)
    
    # Check if object fits within grid bounds
    if x < 0 or y < 0 or x + grid_obj_width > grid_width or y + grid_obj_height > grid_height:
        return False
    
    # Check if position overlaps with any occupied area
    for ox, oy in occupied_positions:
        if x < ox + 1 and x + grid_obj_width > ox and y < oy + 1 and y + grid_obj_height > oy:
            return False
    
    return True

def add_occupied_positions(x, y, obj_type, occupied_positions):
    """Add all grid cells occupied by an object to the occupied positions set"""
    if obj_type not in OBJECT_DIMENSIONS:
        occupied_positions.add((x, y))
        return
    
    dims = OBJECT_DIMENSIONS[obj_type]
    width = dims['width']
    height = dims['height']
    
    # Convert inches to grid cells
    grid_obj_width = max(1, width // GRID_CELL_SIZE)
    grid_obj_height = max(1, height // GRID_CELL_SIZE)
    
    # Add all grid cells occupied by this object
    for dx in range(grid_obj_width):
        for dy in range(grid_obj_height):
            occupied_positions.add((x + dx, y + dy))

@app.route('/random-auto-placer', methods=['POST'])
def random_auto_placer():
    data = request.json
    
    # Get grid dimensions from request, default to 8x8
    grid_width = data.get('grid_width', 8)
    grid_height = data.get('grid_height', 8)
    
    # Define the objects to place
    objects_to_place = ['bed', 'desk', 'window', 'door']
    
    # Placement rules for valid configuration
    placements = []
    occupied_positions = set()
    
    # Place door first (usually on walls)
    door_placed = False
    attempts = 0
    while not door_placed and attempts < 50:
        door_x = random.choice([0, grid_width - 1])  # Left or right wall
        door_y = random.randint(0, grid_height - 1)
        
        if is_position_valid(door_x, door_y, 'door', occupied_positions, grid_width, grid_height):
            placements.append({"x": door_x, "y": door_y, "type": "door"})
            add_occupied_positions(door_x, door_y, 'door', occupied_positions)
            door_placed = True
        attempts += 1
    
    # Place window (usually on walls, opposite to door when possible)
    window_placed = False
    attempts = 0
    while not window_placed and attempts < 50:
        # Try to place window on opposite wall from door
        if door_placed and len(placements) > 0:
            door_pos = placements[0]
            if door_pos['x'] == 0:
                window_x = grid_width - 1
            elif door_pos['x'] == grid_width - 1:
                window_x = 0
            else:
                window_x = random.choice([0, grid_width - 1])
        else:
            window_x = random.choice([0, grid_width - 1])
        
        window_y = random.randint(0, grid_height - 1)
        
        if is_position_valid(window_x, window_y, 'window', occupied_positions, grid_width, grid_height):
            placements.append({"x": window_x, "y": window_y, "type": "window"})
            add_occupied_positions(window_x, window_y, 'window', occupied_positions)
            window_placed = True
        attempts += 1
    
    # Place bed (avoid walls, need space around it)
    bed_placed = False
    attempts = 0
    while not bed_placed and attempts < 100:
        bed_x = random.randint(1, grid_width - 3)  # Avoid walls, leave space for bed
        bed_y = random.randint(1, grid_height - 3)
        
        if is_position_valid(bed_x, bed_y, 'bed', occupied_positions, grid_width, grid_height):
            placements.append({"x": bed_x, "y": bed_y, "type": "bed"})
            add_occupied_positions(bed_x, bed_y, 'bed', occupied_positions)
            bed_placed = True
        attempts += 1
    
    # Place desk (avoid walls, need some space)
    desk_placed = False
    attempts = 0
    while not desk_placed and attempts < 100:
        desk_x = random.randint(1, grid_width - 2)
        desk_y = random.randint(1, grid_height - 2)
        
        if is_position_valid(desk_x, desk_y, 'desk', occupied_positions, grid_width, grid_height):
            placements.append({"x": desk_x, "y": desk_y, "type": "desk"})
            add_occupied_positions(desk_x, desk_y, 'desk', occupied_positions)
            desk_placed = True
        attempts += 1
    
    return jsonify({
        "placements": placements,
        "clear_grid": True  # Indicate that the grid should be cleared first
    })

if __name__ == '__main__':
    app.run(port=5000) 
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
                "desk": {"width": 48, "height": 24, "icon": "chair", "type": "furniture"},
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

def is_boundary(obj_type):
    """Check if object is a boundary (door/window)"""
    return obj_type in OBJECT_DIMENSIONS and OBJECT_DIMENSIONS[obj_type]["type"] == "boundary"

def get_boundary_span(obj_type):
    """Get the span (in grid cells) for a boundary based on its length in inches"""
    if obj_type not in OBJECT_DIMENSIONS:
        return 30  # Default 30 inches
    
    dims = OBJECT_DIMENSIONS[obj_type]
    length_inches = dims['width']  # Use width as length for boundaries
    return length_inches  # Use actual inch value (1 grid cell = 1 inch)

def get_object_grid_dimensions(obj_type):
    """Get the grid dimensions (width, height) for an object in grid cells"""
    if obj_type not in OBJECT_DIMENSIONS:
        return (1, 1)
    
    dims = OBJECT_DIMENSIONS[obj_type]
    width = dims['width']
    height = dims['height']
    
    # Convert inches to grid cells (1 inch = 1 grid cell)
    grid_width = max(1, width)
    grid_height = max(1, height)
    
    return (grid_width, grid_height)

def get_object_polygon(obj_type, x, y):
    """Get the polygon points for an object at position (x, y)"""
    if obj_type not in OBJECT_DIMENSIONS:
        return [(x, y), (x+1, y), (x+1, y+1), (x, y+1)]  # Default 1x1
    
    # Boundaries don't take up grid space
    if is_boundary(obj_type):
        return [(x, y)]
    
    grid_width, grid_height = get_object_grid_dimensions(obj_type)
    
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
        print(f"DEBUG: {obj_type} not found in OBJECT_DIMENSIONS")
        return False
    
    # Boundaries can be placed on walls
    if is_boundary(obj_type):
        # Check if position is on a wall
        is_on_wall = (x == 0 or x == grid_width - 1 or y == 0 or y == grid_height - 1)
        if not is_on_wall:
            print(f"DEBUG: {obj_type} at ({x}, {y}) not on wall")
            return False
        
        # Check if boundary fits within grid bounds
        span = get_boundary_span(obj_type)
        print(f"DEBUG: {obj_type} span: {span}, position: ({x}, {y}), grid: {grid_width}x{grid_height}")
        
        if (x == 0 or x == grid_width - 1):  # Vertical wall
            if y < 0 or y + span > grid_height:
                print(f"DEBUG: {obj_type} extends beyond grid height: y={y} + span={span} > {grid_height}")
                return False  # Boundary extends beyond grid height
        elif (y == 0 or y == grid_height - 1):  # Horizontal wall
            if x < 0 or x + span > grid_width:
                print(f"DEBUG: {obj_type} extends beyond grid width: x={x} + span={span} > {grid_width}")
                return False  # Boundary extends beyond grid width
        
        print(f"DEBUG: {obj_type} at ({x}, {y}) is valid")
        return True
    
    # Regular objects
    grid_obj_width, grid_obj_height = get_object_grid_dimensions(obj_type)
    print(f"DEBUG: {obj_type} dimensions: {grid_obj_width}x{grid_obj_height}, position: ({x}, {y}), grid: {grid_width}x{grid_height}")
    
    # Check if object fits within grid bounds (all corners must be within bounds)
    if (x < 0 or y < 0 or 
        x + grid_obj_width > grid_width or 
        y + grid_obj_height > grid_height):
        print(f"DEBUG: {obj_type} at ({x}, {y}) doesn't fit in grid bounds")
        print(f"DEBUG: Object would occupy: ({x},{y}) to ({x + grid_obj_width},{y + grid_obj_height})")
        print(f"DEBUG: Grid bounds: (0,0) to ({grid_width},{grid_height})")
        return False
    
    print(f"DEBUG: {obj_type} at ({x}, {y}) fits in grid bounds")
    return True

def check_object_collision(x, y, obj_type, occupied_positions):
    """Check if an object placement would collide with occupied positions"""
    if is_boundary(obj_type):
        print(f"DEBUG: {obj_type} is boundary, no collision check needed")
        return False  # Boundaries don't collide with regular objects
    
    grid_obj_width, grid_obj_height = get_object_grid_dimensions(obj_type)
    print(f"DEBUG: Checking collision for {obj_type} at ({x}, {y}), size: {grid_obj_width}x{grid_obj_height}")
    print(f"DEBUG: Occupied positions: {occupied_positions}")
    
    # Check each cell the object would occupy
    for dx in range(grid_obj_width):
        for dy in range(grid_obj_height):
            check_x = x + dx
            check_y = y + dy
            if (check_x, check_y) in occupied_positions:
                print(f"DEBUG: Collision detected at ({check_x}, {check_y})")
                return True  # Collision detected
    
    print(f"DEBUG: No collision detected for {obj_type} at ({x}, {y})")
    return False

def add_occupied_positions(x, y, obj_type, occupied_positions):
    """Add all grid cells occupied by an object to the occupied positions set"""
    if obj_type not in OBJECT_DIMENSIONS:
        occupied_positions.add((x, y))
        print(f"DEBUG: Added unknown object at ({x}, {y}) to occupied positions")
        return
    
    # Boundaries don't occupy grid space
    if is_boundary(obj_type):
        print(f"DEBUG: {obj_type} is boundary, not adding to occupied positions")
        return
    
    grid_obj_width, grid_obj_height = get_object_grid_dimensions(obj_type)
    print(f"DEBUG: Adding {obj_type} at ({x}, {y}) to occupied positions, size: {grid_obj_width}x{grid_obj_height}")
    
    # Add all grid cells occupied by this object
    cells_added = []
    for dx in range(grid_obj_width):
        for dy in range(grid_obj_height):
            cell = (x + dx, y + dy)
            occupied_positions.add(cell)
            cells_added.append(cell)
    
    print(f"DEBUG: Added {len(cells_added)} cells for {obj_type}: {cells_added[:5]}{'...' if len(cells_added) > 5 else ''}")
    print(f"DEBUG: Total occupied positions after {obj_type}: {len(occupied_positions)} cells")

@app.route('/random-auto-placer', methods=['POST'])
def random_auto_placer():
    data = request.json
    
    # Get grid dimensions from request, default to 8x8
    grid_width = data.get('grid_width', 8)
    grid_height = data.get('grid_height', 8)
    
    print(f"DEBUG: Starting auto placement for grid {grid_width}x{grid_height}")
    
    # Define the objects to place
    objects_to_place = ['bed', 'desk', 'window', 'door']
    
    # Placement rules for valid configuration
    placements = []
    occupied_positions = set()
    
    # Place door first (usually on walls)
    door_placed = False
    attempts = 0
    print("DEBUG: Attempting to place door...")
    while not door_placed and attempts < 100:
        # Place door on walls with proper bounds checking
        door_span = get_boundary_span('door')
        if random.choice([True, False]):  # Horizontal wall
            door_x = random.randint(0, max(0, grid_width - door_span))
            door_y = random.choice([0, grid_height - 1])
        else:  # Vertical wall
            door_x = random.choice([0, grid_width - 1])
            door_y = random.randint(0, max(0, grid_height - door_span))
        
        print(f"DEBUG: Door attempt {attempts + 1}: position ({door_x}, {door_y})")
        
        if is_position_valid(door_x, door_y, 'door', occupied_positions, grid_width, grid_height):
            print(f"DEBUG: Door placement successful at ({door_x}, {door_y})")
            placements.append({"x": door_x, "y": door_y, "type": "door"})
            add_occupied_positions(door_x, door_y, 'door', occupied_positions)
            door_placed = True
        else:
            print(f"DEBUG: Door placement failed at ({door_x}, {door_y})")
        attempts += 1
    
    # Place window (usually on walls, opposite to door when possible)
    window_placed = False
    attempts = 0
    print("DEBUG: Attempting to place window...")
    while not window_placed and attempts < 100:
        window_span = get_boundary_span('window')
        # Try to place window on opposite wall from door
        if door_placed and len(placements) > 0:
            door_pos = placements[0]
            # Place window on opposite wall
            if door_pos['x'] == 0:
                window_x = grid_width - 1
                window_y = random.randint(0, max(0, grid_height - window_span))
            elif door_pos['x'] == grid_width - 1:
                window_x = 0
                window_y = random.randint(0, max(0, grid_height - window_span))
            elif door_pos['y'] == 0:
                window_x = random.randint(0, max(0, grid_width - window_span))
                window_y = grid_height - 1
            elif door_pos['y'] == grid_height - 1:
                window_x = random.randint(0, max(0, grid_width - window_span))
                window_y = 0
            else:
                # Fallback to random wall placement
                if random.choice([True, False]):  # Horizontal wall
                    window_x = random.randint(0, max(0, grid_width - window_span))
                    window_y = random.choice([0, grid_height - 1])
                else:  # Vertical wall
                    window_x = random.choice([0, grid_width - 1])
                    window_y = random.randint(0, max(0, grid_height - window_span))
        else:
            # Random wall placement
            if random.choice([True, False]):  # Horizontal wall
                window_x = random.randint(0, max(0, grid_width - window_span))
                window_y = random.choice([0, grid_height - 1])
            else:  # Vertical wall
                window_x = random.choice([0, grid_width - 1])
                window_y = random.randint(0, max(0, grid_height - window_span))
        
        print(f"DEBUG: Window attempt {attempts + 1}: position ({window_x}, {window_y})")
        
        if is_position_valid(window_x, window_y, 'window', occupied_positions, grid_width, grid_height):
            print(f"DEBUG: Window placement successful at ({window_x}, {window_y})")
            placements.append({"x": window_x, "y": window_y, "type": "window"})
            add_occupied_positions(window_x, window_y, 'window', occupied_positions)
            window_placed = True
        else:
            print(f"DEBUG: Window placement failed at ({window_x}, {window_y})")
        attempts += 1
    
    # Place bed (avoid walls, need space around it)
    bed_placed = False
    attempts = 0
    print("DEBUG: Attempting to place bed...")
    bed_width, bed_height = get_object_grid_dimensions('bed')
    while not bed_placed and attempts < 200:
        # Ensure bed fits within grid bounds
        bed_x = random.randint(0, max(0, grid_width - bed_width))
        bed_y = random.randint(0, max(0, grid_height - bed_height))
        
        print(f"DEBUG: Bed attempt {attempts + 1}: position ({bed_x}, {bed_y})")
        
        if (is_position_valid(bed_x, bed_y, 'bed', occupied_positions, grid_width, grid_height) and
            not check_object_collision(bed_x, bed_y, 'bed', occupied_positions)):
            print(f"DEBUG: Bed placement successful at ({bed_x}, {bed_y})")
            placements.append({"x": bed_x, "y": bed_y, "type": "bed"})
            add_occupied_positions(bed_x, bed_y, 'bed', occupied_positions)
            bed_placed = True
        else:
            print(f"DEBUG: Bed placement failed at ({bed_x}, {bed_y})")
        attempts += 1
    
    # Place desk (avoid walls, need some space)
    desk_placed = False
    attempts = 0
    print("DEBUG: Attempting to place desk...")
    desk_width, desk_height = get_object_grid_dimensions('desk')
    while not desk_placed and attempts < 200:
        # Ensure desk fits within grid bounds
        desk_x = random.randint(0, max(0, grid_width - desk_width))
        desk_y = random.randint(0, max(0, grid_height - desk_height))
        
        print(f"DEBUG: Desk attempt {attempts + 1}: position ({desk_x}, {desk_y})")
        
        if (is_position_valid(desk_x, desk_y, 'desk', occupied_positions, grid_width, grid_height) and
            not check_object_collision(desk_x, desk_y, 'desk', occupied_positions)):
            print(f"DEBUG: Desk placement successful at ({desk_x}, {desk_y})")
            placements.append({"x": desk_x, "y": desk_y, "type": "desk"})
            add_occupied_positions(desk_x, desk_y, 'desk', occupied_positions)
            desk_placed = True
        else:
            print(f"DEBUG: Desk placement failed at ({desk_x}, {desk_y})")
        attempts += 1
    
    print(f"DEBUG: Final placements: {placements}")
    print(f"DEBUG: Final occupied positions: {occupied_positions}")
    
    return jsonify({
        "placements": placements,
        "clear_grid": True  # Indicate that the grid should be cleared first
    })

if __name__ == '__main__':
    app.run(port=5000) 
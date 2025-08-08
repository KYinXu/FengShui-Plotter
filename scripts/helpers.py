import json
import os
import random

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
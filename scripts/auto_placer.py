from flask import Flask, request, jsonify
import random
from helpers import (
    is_position_valid,
    check_object_collision,
    add_occupied_positions,
    get_boundary_span,
    get_object_grid_dimensions
)

app = Flask(__name__)

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
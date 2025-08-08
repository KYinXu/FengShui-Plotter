import random
import math
from typing import List, Dict, Tuple, Optional
from helpers import (
    is_position_valid,
    check_object_collision,
    add_occupied_positions,
    get_boundary_span,
    get_object_grid_dimensions,
    OBJECT_DIMENSIONS
)

class FengShuiOptimizer:
    """
    Hill-climbing algorithm for optimizing furniture layouts based on Feng Shui principles.
    """
    
    def __init__(self, grid_width: int, grid_height: int, config: Optional[Dict] = None):
        """
        Initialize the Feng Shui optimizer.
        
        Args:
            grid_width: Width of the grid in cells
            grid_height: Height of the grid in cells
            config: Configuration dictionary for Feng Shui parameters
        """
        self.grid_width = grid_width
        self.grid_height = grid_height
        
        # Default Feng Shui configuration
        self.config = config or {
            # Bagua map weights (1-10 scale)
            'bagua_weights': {
                'career': 8,      # North
                'knowledge': 7,    # Northeast
                'family': 6,       # East
                'wealth': 9,       # Southeast
                'fame': 5,         # South
                'relationships': 8, # Southwest
                'children': 6,     # West
                'helpful_people': 7, # Northwest
                'health': 8        # Center
            },
            
            # Furniture placement preferences
            'furniture_preferences': {
                'bed': {
                    'preferred_zones': ['health', 'relationships', 'family'],
                    'avoid_zones': ['career', 'fame'],
                    'command_position': True,  # Bed should face door
                    'wall_placement': True,    # Bed should be against wall
                    'weight': 10
                },
                'desk': {
                    'preferred_zones': ['career', 'knowledge', 'wealth'],
                    'avoid_zones': ['health', 'relationships'],
                    'command_position': True,  # Desk should face door
                    'window_placement': True,  # Desk near window for natural light
                    'weight': 8
                },
                'door': {
                    'preferred_zones': ['career', 'helpful_people'],
                    'avoid_zones': ['health'],
                    'weight': 6
                },
                'window': {
                    'preferred_zones': ['knowledge', 'wealth'],
                    'avoid_zones': ['health'],
                    'weight': 5
                }
            },
            
            # Energy flow parameters
            'energy_flow': {
                'chi_path_weight': 7,      # Weight for clear chi paths
                'clutter_penalty': 8,      # Penalty for cluttered areas
                'balance_weight': 6,       # Weight for balanced layout
                'command_position_weight': 9  # Weight for command position
            },
            
            # Feng Shui penalty weights
            'feng_shui_penalties': {
                'bed_away_from_wall': 150.0,      # Penalty for bed not against wall
                'door_at_bed_foot': 200.0,        # Penalty for door at foot of bed
                'window_next_to_door': 100.0,     # Penalty for window too close to door
                'same_wall_door_window': 150.0,   # Extra penalty for door/window on same wall
                'bed_under_window': 120.0,        # Penalty for bed under window
                'door_facing_bed': 180.0          # Penalty for door directly facing bed
            },
            
            # Algorithm parameters
            'algorithm': {
                'max_iterations': 1000,
                'max_no_improvement': 100,
                'temperature': 1.0,
                'cooling_rate': 0.95,
                'mutation_rate': 0.3
            }
        }
        
        # Initialize bagua map
        self.bagua_map = self._create_bagua_map()
    
    def _create_bagua_map(self) -> Dict[Tuple[int, int], str]:
        """
        Create a bagua map overlay for the grid.
        Returns a dictionary mapping grid positions to bagua zones.
        """
        bagua_map = {}
        
        # Calculate zone sizes
        zone_width = self.grid_width // 3
        zone_height = self.grid_height // 3
        
        # Define bagua zones (3x3 grid)
        zones = [
            ['career', 'knowledge', 'family'],
            ['helpful_people', 'health', 'wealth'],
            ['children', 'relationships', 'fame']
        ]
        
        # Map each grid position to its bagua zone
        for y in range(self.grid_height):
            for x in range(self.grid_width):
                zone_x = min(x // zone_width, 2)
                zone_y = min(y // zone_height, 2)
                bagua_map[(x, y)] = zones[zone_y][zone_x]
        
        return bagua_map
    
    def _get_bagua_zone(self, x: int, y: int) -> str:
        """Get the bagua zone for a given position."""
        return self.bagua_map.get((x, y), 'health')
    
    def _calculate_bagua_score(self, placement: Dict) -> float:
        """Calculate Bagua score for a placement."""
        x, y = placement['x'], placement['y']
        obj_type = placement['type']
        
        # Get object dimensions
        obj_width, obj_height = get_object_grid_dimensions(obj_type)
        
        # Calculate center of object
        center_x = x + obj_width / 2
        center_y = y + obj_height / 2
        
        # Map to Bagua zones (3x3 grid)
        zone_x = int((center_x / self.grid_width) * 3)
        zone_y = int((center_y / self.grid_height) * 3)
        zone_x = min(2, max(0, zone_x))
        zone_y = min(2, max(0, zone_y))
        
        # Bagua zone preferences for different objects
        bagua_preferences = {
            'bed': [8, 7, 6, 5, 4, 3, 2, 1, 0],  # Prefer back zones
            'desk': [6, 7, 8, 3, 4, 5, 0, 1, 2],  # Prefer front zones
            'door': [6, 3, 0, 7, 4, 1, 8, 5, 2],  # Prefer left zones
            'window': [2, 5, 8, 1, 4, 7, 0, 3, 6],  # Prefer right zones
        }
        
        zone_index = zone_y * 3 + zone_x
        preferences = bagua_preferences.get(obj_type, [4, 4, 4, 4, 4, 4, 4, 4, 4])
        zone_score = preferences[zone_index]
        
        return zone_score * 15.0  # Increased from 10.0

    def _calculate_command_position_score(self, placements: List[Dict]) -> float:
        """Calculate command position score (bed should face door)."""
        bed_placement = None
        door_placement = None
        
        for placement in placements:
            if placement['type'] == 'bed':
                bed_placement = placement
            elif placement['type'] == 'door':
                door_placement = placement
        
        if not bed_placement or not door_placement:
            return 0.0
        
        # Calculate distance between bed and door
        bed_x, bed_y = bed_placement['x'], bed_placement['y']
        door_x, door_y = door_placement['x'], door_placement['y']
        
        distance = math.sqrt((bed_x - door_x)**2 + (bed_y - door_y)**2)
        
        # Optimal distance is moderate (not too close, not too far)
        optimal_distance = min(self.grid_width, self.grid_height) * 0.3
        distance_score = max(0, 50 - abs(distance - optimal_distance))
        
        return distance_score * 2.0  # Increased from 1.0

    def _calculate_chi_flow_score(self, placements: List[Dict]) -> float:
        """Calculate chi flow score (energy flow through space)."""
        if len(placements) < 2:
            return 0.0
        
        total_score = 0.0
        
        # Check spacing between objects
        for i, placement1 in enumerate(placements):
            for j, placement2 in enumerate(placements):
                if i >= j:
                    continue
                
                x1, y1 = placement1['x'], placement1['y']
                x2, y2 = placement2['x'], placement2['y']
                
                distance = math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
                
                # Optimal spacing is moderate
                if 5 <= distance <= 20:
                    total_score += 20.0  # Increased from 10.0
                elif distance < 5:
                    total_score -= 10.0  # Penalty for too close
                else:
                    total_score += 5.0  # Small bonus for far apart
        
        # Bonus for balanced layout (objects not all clustered)
        if len(placements) > 2:
            # Calculate center of mass
            center_x = sum(p['x'] for p in placements) / len(placements)
            center_y = sum(p['y'] for p in placements) / len(placements)
            
            # Calculate spread
            spread = sum(math.sqrt((p['x'] - center_x)**2 + (p['y'] - center_y)**2) for p in placements)
            spread_score = min(50, spread / len(placements))
            total_score += spread_score
        
        return total_score

    def _calculate_feng_shui_penalties(self, placements: List[Dict]) -> float:
        """
        Calculate penalties for specific Feng Shui violations.
        """
        penalty_score = 0.0
        
        # Find bed, door, and window placements
        bed_placement = None
        door_placement = None
        window_placement = None
        
        for placement in placements:
            if placement['type'] == 'bed':
                bed_placement = placement
            elif placement['type'] == 'door':
                door_placement = placement
            elif placement['type'] == 'window':
                window_placement = placement
        
        # Penalty 1: Bed away from walls (bed should be against a wall)
        if bed_placement:
            x, y = bed_placement['x'], bed_placement['y']
            bed_width, bed_height = get_object_grid_dimensions('bed')
            
            # Check if bed is against any wall
            against_wall = (x == 0 or x + bed_width >= self.grid_width - 1 or 
                           y == 0 or y + bed_height >= self.grid_height - 1)
            
            if not against_wall:
                penalty_weight = self.config['feng_shui_penalties']['bed_away_from_wall']
                penalty_score -= penalty_weight
                print(f"DEBUG: Bed penalty - not against wall at ({x}, {y})")
        
        # Penalty 2: Door across the foot of the bed (door should not be at foot of bed)
        if bed_placement and door_placement:
            bed_x, bed_y = bed_placement['x'], bed_placement['y']
            door_x, door_y = door_placement['x'], door_placement['y']
            bed_width, bed_height = get_object_grid_dimensions('bed')
            
            # Calculate bed foot position (assuming bed head is at the top)
            bed_foot_x = bed_x + bed_width // 2  # Center of bed foot
            bed_foot_y = bed_y + bed_height  # Bottom of bed
            
            # Check if door is near the foot of the bed
            distance_to_foot = math.sqrt((door_x - bed_foot_x)**2 + (door_y - bed_foot_y)**2)
            
            if distance_to_foot < 8:  # Door too close to bed foot
                penalty_weight = self.config['feng_shui_penalties']['door_at_bed_foot']
                penalty_score -= penalty_weight
                print(f"DEBUG: Door penalty - too close to bed foot, distance: {distance_to_foot:.2f}")
        
        # Penalty 3: Window directly next to door (should have some separation)
        if door_placement and window_placement:
            door_x, door_y = door_placement['x'], door_placement['y']
            window_x, window_y = window_placement['x'], window_placement['y']
            
            # Calculate distance between door and window
            door_window_distance = math.sqrt((door_x - window_x)**2 + (door_y - window_y)**2)
            
            if door_window_distance < 6:  # Window too close to door
                penalty_weight = self.config['feng_shui_penalties']['window_next_to_door']
                penalty_score -= penalty_weight
                print(f"DEBUG: Window penalty - too close to door, distance: {door_window_distance:.2f}")
            
            # Additional penalty if door and window are on the same wall
            door_on_wall = (door_x == 0 or door_x == self.grid_width - 1 or 
                           door_y == 0 or door_y == self.grid_height - 1)
            window_on_wall = (window_x == 0 or window_x == self.grid_width - 1 or 
                             window_y == 0 or window_y == self.grid_height - 1)
            
            if door_on_wall and window_on_wall:
                # Check if they're on the same wall side
                same_wall = ((door_x == 0 and window_x == 0) or 
                            (door_x == self.grid_width - 1 and window_x == self.grid_width - 1) or
                            (door_y == 0 and window_y == 0) or 
                            (door_y == self.grid_height - 1 and window_y == self.grid_height - 1))
                
                if same_wall and door_window_distance < 12:
                    penalty_weight = self.config['feng_shui_penalties']['same_wall_door_window']
                    penalty_score -= penalty_weight
                    print(f"DEBUG: Same wall penalty - door and window on same wall, distance: {door_window_distance:.2f}")
        
        # Penalty 4: Bed directly under window (bed should not be under window)
        if bed_placement and window_placement:
            bed_x, bed_y = bed_placement['x'], bed_placement['y']
            window_x, window_y = window_placement['x'], window_placement['y']
            bed_width, bed_height = get_object_grid_dimensions('bed')
            
            # Check if bed is positioned under or very close to window
            bed_center_x = bed_x + bed_width // 2
            bed_center_y = bed_y + bed_height // 2
            
            distance_to_window = math.sqrt((bed_center_x - window_x)**2 + (bed_center_y - window_y)**2)
            
            if distance_to_window < 10:  # Bed too close to window
                penalty_weight = self.config['feng_shui_penalties']['bed_under_window']
                penalty_score -= penalty_weight
                print(f"DEBUG: Bed under window penalty - distance: {distance_to_window:.2f}")
        
        # Penalty 5: Door facing bed directly (door should not directly face bed)
        if bed_placement and door_placement:
            bed_x, bed_y = bed_placement['x'], bed_placement['y']
            door_x, door_y = door_placement['x'], door_placement['y']
            bed_width, bed_height = get_object_grid_dimensions('bed')
            
            # Calculate bed center
            bed_center_x = bed_x + bed_width // 2
            bed_center_y = bed_y + bed_height // 2
            
            # Check if door directly faces bed center
            door_to_bed_distance = math.sqrt((door_x - bed_center_x)**2 + (door_y - bed_center_y)**2)
            
            if door_to_bed_distance < 15:  # Door too close to bed center
                penalty_weight = self.config['feng_shui_penalties']['door_facing_bed']
                penalty_score -= penalty_weight
                print(f"DEBUG: Door facing bed penalty - distance: {door_to_bed_distance:.2f}")
        
        return penalty_score

    def _calculate_layout_score(self, placements: List[Dict]) -> float:
        """
        Calculate the overall Feng Shui score for a layout.
        """
        if not placements:
            return 0.0
        
        total_score = 0.0
        
        # Check for invalid configurations first - extremely negative scores
        invalid_score = self._check_invalid_configurations(placements)
        if invalid_score < -1000:  # If there are invalid configurations
            return invalid_score
        
        # Bagua scores
        for placement in placements:
            bagua_score = self._calculate_bagua_score(placement)
            weight = self.config['furniture_preferences'].get(
                placement['type'], {}).get('weight', 1)
            total_score += bagua_score * weight
        
        # Command position score
        command_score = self._calculate_command_position_score(placements)
        total_score += command_score
        
        # Chi flow score
        chi_score = self._calculate_chi_flow_score(placements)
        total_score += chi_score
        
        # Bonus for having all required objects
        total_score += len(placements) * 25.0  # Increased bonus for complete layouts
        
        # Bonus for wall placement of boundaries
        for placement in placements:
            if placement['type'] in ['door', 'window']:
                x, y = placement['x'], placement['y']
                if (x == 0 or x == self.grid_width - 1 or 
                    y == 0 or y == self.grid_height - 1):
                    total_score += 30.0  # Increased from previous values
        
        # Apply Feng Shui penalties
        feng_shui_penalties = self._calculate_feng_shui_penalties(placements)
        total_score += feng_shui_penalties
        
        return total_score
    
    def _check_invalid_configurations(self, placements: List[Dict]) -> float:
        """
        Check for invalid configurations and return extremely negative scores.
        """
        score = 0.0
        
        # Check each placement for bounds violations
        for placement in placements:
            x, y = placement['x'], placement['y']
            obj_type = placement['type']
            
            # Get object dimensions
            if obj_type in ['bed', 'desk']:
                obj_width, obj_height = get_object_grid_dimensions(obj_type)
                
                # Check if object extends beyond grid bounds
                if (x < 0 or y < 0 or 
                    x + obj_width > self.grid_width or 
                    y + obj_height > self.grid_height):
                    print(f"DEBUG: {obj_type} at ({x}, {y}) extends beyond grid bounds")
                    score -= 10000  # Extremely negative score for out-of-bounds
                    return score
        
        # Check for overlapping objects (bed and desk)
        furniture_placements = [p for p in placements if p['type'] in ['bed', 'desk']]
        
        for i, placement1 in enumerate(furniture_placements):
            for j, placement2 in enumerate(furniture_placements):
                if i >= j:  # Skip self-comparison and duplicate comparisons
                    continue
                
                # Check if these objects overlap
                if self._objects_overlap(placement1, placement2):
                    print(f"DEBUG: {placement1['type']} and {placement2['type']} overlap")
                    score -= 10000  # Extremely negative score for overlap
                    return score
        
        return score
    
    def _objects_overlap(self, placement1: Dict, placement2: Dict) -> bool:
        """
        Check if two objects overlap.
        """
        x1, y1 = placement1['x'], placement1['y']
        x2, y2 = placement2['x'], placement2['y']
        type1, type2 = placement1['type'], placement2['type']
        
        # Get dimensions
        width1, height1 = get_object_grid_dimensions(type1)
        width2, height2 = get_object_grid_dimensions(type2)
        
        # Check for overlap using bounding box intersection
        return not (x1 + width1 <= x2 or x2 + width2 <= x1 or 
                   y1 + height1 <= y2 or y2 + height2 <= y1)
    
    def _generate_random_placement(self, obj_type: str) -> Dict:
        """Generate a random valid placement for an object."""
        max_attempts = 1000  # Increased attempts
        
        for attempt in range(max_attempts):
            # Generate random position
            x = random.randint(0, self.grid_width - 1)
            y = random.randint(0, self.grid_height - 1)
            
            # Check if position is valid
            if is_position_valid(x, y, obj_type, set(), self.grid_width, self.grid_height):
                return {'type': obj_type, 'x': x, 'y': y}
        
        # If no valid position found, return a safe default
        print(f"WARNING: Could not find valid position for {obj_type}, using origin")
        return {'type': obj_type, 'x': 0, 'y': 0}

    def _generate_initial_layout(self, objects_to_place: List[str]) -> List[Dict]:
        """Generate an initial random layout with all objects placed."""
        placements = []
        occupied_positions = set()
        
        print(f"DEBUG: Starting initial layout generation for objects: {objects_to_place}")
        
        # Sort objects to prioritize desk placement
        sorted_objects = sorted(objects_to_place, key=lambda x: (x != 'desk', x))  # Put desk first
        print(f"DEBUG: Sorted objects for placement: {sorted_objects}")
        
        # Try to place each object with multiple attempts
        for obj_type in sorted_objects:
            placement = None
            max_attempts = 1000  # Increased attempts
            print(f"DEBUG: Attempting to place {obj_type}...")
            
            for attempt in range(max_attempts):
                temp_placement = self._generate_random_placement(obj_type)
                
                # Check if this placement is valid and doesn't collide
                is_valid = is_position_valid(temp_placement['x'], temp_placement['y'], obj_type, occupied_positions, self.grid_width, self.grid_height)
                no_collision = not check_object_collision(temp_placement['x'], temp_placement['y'], obj_type, occupied_positions)
                
                if is_valid and no_collision:
                    placement = temp_placement
                    print(f"DEBUG: Successfully placed {obj_type} at ({temp_placement['x']}, {temp_placement['y']}) on attempt {attempt + 1}")
                    break
                elif attempt % 200 == 0:  # Log every 200th attempt
                    print(f"DEBUG: {obj_type} attempt {attempt + 1}: valid={is_valid}, no_collision={no_collision}")
            
            # If we couldn't find a valid placement, force place it at origin
            if placement is None:
                print(f"WARNING: Could not find valid placement for {obj_type}, placing at origin")
                placement = {'type': obj_type, 'x': 0, 'y': 0}
            
            # Add the placement and update occupied positions
            placements.append(placement)
            add_occupied_positions(placement['x'], placement['y'], obj_type, occupied_positions)
            print(f"DEBUG: Added {obj_type} to layout at ({placement['x']}, {placement['y']})")
        
        print(f"DEBUG: Initial layout generated with {len(placements)} objects: {[p['type'] for p in placements]}")
        return placements
    
    def _mutate_placement(self, placement: Dict) -> Dict:
        """Create a mutated version of a placement."""
        new_placement = placement.copy()
        
        # Randomly adjust position with larger range for better exploration
        x, y = placement['x'], placement['y']
        obj_type = placement['type']
        
        # Get object dimensions for bounds checking
        obj_width, obj_height = get_object_grid_dimensions(obj_type)
        
        # Larger random adjustment for better exploration
        dx = random.randint(-8, 8)  # Increased from -3,3
        dy = random.randint(-8, 8)  # Increased from -3,3
        
        # Calculate new position with bounds checking
        new_x = max(0, min(self.grid_width - obj_width, x + dx))
        new_y = max(0, min(self.grid_height - obj_height, y + dy))
        
        new_placement['x'] = new_x
        new_placement['y'] = new_y
        
        return new_placement
    
    def _is_valid_layout(self, placements: List[Dict]) -> bool:
        """Check if a layout is valid (no collisions, within bounds)."""
        occupied_positions = set()
        
        for placement in placements:
            x, y = placement['x'], placement['y']
            obj_type = placement['type']
            
            # Check bounds and collisions
            if not is_position_valid(x, y, obj_type, occupied_positions, self.grid_width, self.grid_height):
                print(f"DEBUG: Invalid position for {obj_type} at ({x}, {y})")
                return False
            
            if check_object_collision(x, y, obj_type, occupied_positions):
                print(f"DEBUG: Collision detected for {obj_type} at ({x}, {y})")
                return False
            
            add_occupied_positions(x, y, obj_type, occupied_positions)
        
        # Additional check for overlapping furniture objects
        furniture_placements = [p for p in placements if p['type'] in ['bed', 'desk']]
        for i, placement1 in enumerate(furniture_placements):
            for j, placement2 in enumerate(furniture_placements):
                if i >= j:  # Skip self-comparison and duplicate comparisons
                    continue
                
                if self._objects_overlap(placement1, placement2):
                    print(f"DEBUG: Overlap detected between {placement1['type']} and {placement2['type']}")
                    return False
        
        return True

    def _generate_valid_mutation(self, current_layout: List[Dict], objects_to_place: List[str]) -> List[Dict]:
        """Generate a valid mutated layout that doesn't have overlaps."""
        max_attempts = 50  # Limit attempts to avoid infinite loops
        
        for attempt in range(max_attempts):
            mutated_layout = []
            occupied_positions = set()
            
            # Try to mutate each placement
            for placement in current_layout:
                if random.random() < 0.3:  # 30% chance to mutate each placement
                    # Try to find a valid mutation
                    valid_mutation = None
                    for mutation_attempt in range(20):
                        mutated_placement = self._mutate_placement(placement)
                        
                        # Check if this mutation is valid
                        if (is_position_valid(mutated_placement['x'], mutated_placement['y'], 
                                            mutated_placement['type'], occupied_positions, 
                                            self.grid_width, self.grid_height) and
                            not check_object_collision(mutated_placement['x'], mutated_placement['y'], 
                                                     mutated_placement['type'], occupied_positions)):
                            
                            valid_mutation = mutated_placement
                            break
                    
                    if valid_mutation is not None:
                        mutated_layout.append(valid_mutation)
                        add_occupied_positions(valid_mutation['x'], valid_mutation['y'], 
                                             valid_mutation['type'], occupied_positions)
                    else:
                        # Keep original placement if no valid mutation found
                        mutated_layout.append(placement.copy())
                        add_occupied_positions(placement['x'], placement['y'], 
                                             placement['type'], occupied_positions)
                else:
                    mutated_layout.append(placement.copy())
                    add_occupied_positions(placement['x'], placement['y'], 
                                         placement['type'], occupied_positions)
            
            # Ensure all objects are present
            placed_types = [p['type'] for p in mutated_layout]
            for obj_type in objects_to_place:
                if obj_type not in placed_types:
                    print(f"WARNING: Adding missing {obj_type} to mutated layout")
                    mutated_layout.append({'type': obj_type, 'x': 0, 'y': 0})
            
            # Final validation
            if self._is_valid_layout(mutated_layout):
                return mutated_layout
        
        # If we couldn't generate a valid mutation, return the original layout
        print("WARNING: Could not generate valid mutation, keeping original layout")
        return current_layout.copy()
    
    def optimize_layout(self, objects_to_place: List[str]) -> Tuple[List[Dict], float]:
        """Optimize layout using hill climbing with simulated annealing."""
        print(f"DEBUG: Starting optimization for {len(objects_to_place)} objects")
        
        # Generate initial layout
        current_layout = self._generate_initial_layout(objects_to_place)
        current_score = self._calculate_layout_score(current_layout)
        
        print(f"DEBUG: Initial layout score: {current_score:.2f}")
        
        best_layout = current_layout.copy()
        best_score = current_score
        
        # Hill climbing parameters
        max_iterations = 200  # Increased from 100
        temperature = 100.0  # Starting temperature for simulated annealing
        cooling_rate = 0.95  # Cooling rate
        
        no_improvement_count = 0
        max_no_improvement = 50  # Increased patience
        
        for iteration in range(max_iterations):
            # Generate a valid mutated version of the current layout
            mutated_layout = self._generate_valid_mutation(current_layout, objects_to_place)
            
            # Calculate score for mutated layout
            mutated_score = self._calculate_layout_score(mutated_layout)
            
            # Accept better solutions or worse solutions with probability (simulated annealing)
            accept = False
            if mutated_score > current_score:
                accept = True
                print(f"DEBUG: Accepting better score: {mutated_score:.2f} > {current_score:.2f}")
            elif temperature > 0.1:  # Only accept worse solutions when temperature is high
                acceptance_probability = math.exp((mutated_score - current_score) / temperature)
                if random.random() < acceptance_probability:
                    accept = True
                    print(f"DEBUG: Accepting worse score with probability: {mutated_score:.2f} < {current_score:.2f}")
            
            if accept:
                current_layout = mutated_layout
                current_score = mutated_score
                
                # Update best solution if this is better
                if current_score > best_score:
                    best_layout = current_layout.copy()
                    best_score = current_score
                    no_improvement_count = 0
                    print(f"DEBUG: New best score: {best_score:.2f}")
                else:
                    no_improvement_count += 1
            else:
                no_improvement_count += 1
            
            # Cool down temperature
            temperature *= cooling_rate
            
            # Early stopping if no improvement for too long
            if no_improvement_count >= max_no_improvement:
                print(f"DEBUG: No improvement for {max_no_improvement} iterations, stopping early")
                break
            
            if iteration % 20 == 0:
                print(f"DEBUG: Iteration {iteration}, current score: {current_score:.2f}, best score: {best_score:.2f}, temperature: {temperature:.2f}")
        
        # Final validation and cleanup
        if len(best_layout) != len(objects_to_place):
            print(f"WARNING: Best layout has {len(best_layout)} objects, expected {len(objects_to_place)}")
            print(f"DEBUG: Best layout objects: {[p['type'] for p in best_layout]}")
            print(f"DEBUG: Expected objects: {objects_to_place}")
            
            # Add missing objects at origin if needed
            placed_types = [p['type'] for p in best_layout]
            for obj_type in objects_to_place:
                if obj_type not in placed_types:
                    print(f"Adding missing {obj_type} at origin")
                    best_layout.append({'type': obj_type, 'x': 0, 'y': 0})
        
        # Final verification that all objects are present
        final_types = [p['type'] for p in best_layout]
        print(f"DEBUG: Final layout objects: {final_types}")
        for obj_type in objects_to_place:
            if obj_type not in final_types:
                print(f"ERROR: {obj_type} still missing from final layout!")
                best_layout.append({'type': obj_type, 'x': 0, 'y': 0})
        
        print(f"Final best score: {best_score:.2f}")
        return best_layout, best_score
    
    def get_layout_analysis(self, placements: List[Dict]) -> Dict:
        """
        Get detailed analysis of a layout's Feng Shui properties.
        """
        analysis = {
            'total_score': self._calculate_layout_score(placements),
            'bagua_analysis': {},
            'energy_flow': {
                'command_position_score': self._calculate_command_position_score(placements),
                'chi_flow_score': self._calculate_chi_flow_score(placements)
            },
            'feng_shui_penalties': self._calculate_feng_shui_penalties(placements),
            'recommendations': []
        }
        
        # Analyze each bagua zone
        zone_counts = {}
        for placement in placements:
            zone = self._get_bagua_zone(placement['x'], placement['y'])
            zone_counts[zone] = zone_counts.get(zone, 0) + 1
        
        for zone, count in zone_counts.items():
            analysis['bagua_analysis'][zone] = {
                'count': count,
                'weight': self.config['bagua_weights'][zone],
                'score': count * self.config['bagua_weights'][zone]
            }
        
        # Generate recommendations
        if analysis['total_score'] < 50:
            analysis['recommendations'].append("Consider repositioning furniture for better energy flow")
        
        if analysis['energy_flow']['command_position_score'] < 10:
            analysis['recommendations'].append("Ensure bed and desk face the door for command position")
        
        # Feng Shui specific recommendations
        if analysis['feng_shui_penalties'] < -100:
            analysis['recommendations'].append("Address Feng Shui violations for better energy flow")
        
        if analysis['feng_shui_penalties'] < -200:
            analysis['recommendations'].append("Major Feng Shui issues detected - consider significant layout changes")
        
        return analysis


# Example usage and testing
if __name__ == "__main__":
    # Example configuration
    config = {
        'bagua_weights': {
            'career': 8, 'knowledge': 7, 'family': 6, 'wealth': 9,
            'fame': 5, 'relationships': 8, 'children': 6, 'helpful_people': 7, 'health': 8
        },
        'algorithm': {
            'max_iterations': 500,
            'max_no_improvement': 50,
            'temperature': 1.0,
            'cooling_rate': 0.95,
            'mutation_rate': 0.3
        }
    }
    
    # Create optimizer for a 12x12 room (144x144 inches)
    optimizer = FengShuiOptimizer(144, 144, config)
    
    # Objects to place
    objects = ['bed', 'desk', 'door', 'window']
    
    # Optimize layout
    optimized_layout, score = optimizer.optimize_layout(objects)
    
    print(f"\nOptimized Layout:")
    for placement in optimized_layout:
        zone = optimizer._get_bagua_zone(placement['x'], placement['y'])
        print(f"  {placement['type']}: ({placement['x']}, {placement['y']}) - Zone: {zone}")
    
    # Get detailed analysis
    analysis = optimizer.get_layout_analysis(optimized_layout)
    print(f"\nLayout Analysis:")
    print(f"  Total Score: {analysis['total_score']:.2f}")
    print(f"  Command Position Score: {analysis['energy_flow']['command_position_score']:.2f}")
    print(f"  Chi Flow Score: {analysis['energy_flow']['chi_flow_score']:.2f}")
    print(f"  Feng Shui Penalties: {analysis['feng_shui_penalties']:.2f}")
    
    if analysis['recommendations']:
        print(f"\nRecommendations:")
        for rec in analysis['recommendations']:
            print(f"  - {rec}") 
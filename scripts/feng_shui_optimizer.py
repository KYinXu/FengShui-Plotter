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
        """
        Calculate the bagua score for a placement.
        Higher scores are better.
        """
        obj_type = placement['type']
        x, y = placement['x'], placement['y']
        
        if obj_type not in self.config['furniture_preferences']:
            return 0.0
        
        preferences = self.config['furniture_preferences'][obj_type]
        zone = self._get_bagua_zone(x, y)
        
        # Check if placement is in preferred zones
        if zone in preferences.get('preferred_zones', []):
            return self.config['bagua_weights'][zone]
        
        # Check if placement is in zones to avoid
        if zone in preferences.get('avoid_zones', []):
            return -self.config['bagua_weights'][zone]
        
        # Neutral placement
        return 0.0
    
    def _calculate_command_position_score(self, placements: List[Dict]) -> float:
        """
        Calculate command position score.
        Objects should face the door for good energy flow.
        """
        score = 0.0
        
        # Find door position
        door_placement = None
        for placement in placements:
            if placement['type'] == 'door':
                door_placement = placement
                break
        
        if not door_placement:
            return 0.0
        
        door_x, door_y = door_placement['x'], door_placement['y']
        
        for placement in placements:
            obj_type = placement['type']
            if obj_type in ['bed', 'desk']:
                preferences = self.config['furniture_preferences'][obj_type]
                
                if preferences.get('command_position', False):
                    # Check if object faces the door
                    x, y = placement['x'], placement['y']
                    
                    # Simple command position check
                    if self._faces_door(x, y, door_x, door_y):
                        score += self.config['energy_flow']['command_position_weight']
        
        return score
    
    def _faces_door(self, obj_x: int, obj_y: int, door_x: int, door_y: int) -> bool:
        """
        Check if an object faces the door.
        Simplified implementation - can be enhanced with more sophisticated logic.
        """
        # For now, consider it facing the door if it's not too close and not behind it
        distance = math.sqrt((obj_x - door_x)**2 + (obj_y - door_y)**2)
        return distance > 2 and distance < self.grid_width // 2
    
    def _calculate_chi_flow_score(self, placements: List[Dict]) -> float:
        """
        Calculate chi (energy) flow score.
        Clear paths and balanced layout are preferred.
        """
        score = 0.0
        
        # Create a grid representation
        grid = [[0 for _ in range(self.grid_width)] for _ in range(self.grid_height)]
        
        # Mark occupied positions
        for placement in placements:
            if placement['type'] not in ['door', 'window']:  # Boundaries don't block chi
                x, y = placement['x'], placement['y']
                obj_width, obj_height = get_object_grid_dimensions(placement['type'])
                
                for dx in range(obj_width):
                    for dy in range(obj_height):
                        if 0 <= x + dx < self.grid_width and 0 <= y + dy < self.grid_height:
                            grid[y + dy][x + dx] = 1
        
        # Calculate clear paths (simplified)
        clear_paths = 0
        for y in range(self.grid_height):
            for x in range(self.grid_width):
                if grid[y][x] == 0:
                    # Count clear neighbors
                    clear_neighbors = 0
                    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.grid_width and 0 <= ny < self.grid_height:
                            if grid[ny][nx] == 0:
                                clear_neighbors += 1
                    clear_paths += clear_neighbors
        
        score += clear_paths * self.config['energy_flow']['chi_path_weight']
        
        # Balance penalty (too much furniture in one area)
        for zone in self.config['bagua_weights']:
            zone_count = 0
            for placement in placements:
                x, y = placement['x'], placement['y']
                if self._get_bagua_zone(x, y) == zone:
                    zone_count += 1
            
            if zone_count > 2:  # Too much furniture in one zone
                score -= (zone_count - 2) * self.config['energy_flow']['clutter_penalty']
        
        return score
    
    def _calculate_layout_score(self, placements: List[Dict]) -> float:
        """
        Calculate the overall Feng Shui score for a layout.
        """
        if not placements:
            return 0.0
        
        total_score = 0.0
        
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
        
        return total_score
    
    def _generate_random_placement(self, obj_type: str) -> Dict:
        """Generate a random valid placement for an object."""
        max_attempts = 100
        
        for _ in range(max_attempts):
            if obj_type in ['door', 'window']:
                # Place on walls
                if random.choice([True, False]):  # Horizontal wall
                    x = random.randint(0, self.grid_width - 1)
                    y = random.choice([0, self.grid_height - 1])
                else:  # Vertical wall
                    x = random.choice([0, self.grid_width - 1])
                    y = random.randint(0, self.grid_height - 1)
            else:
                # Place anywhere in the grid
                x = random.randint(0, self.grid_width - 1)
                y = random.randint(0, self.grid_height - 1)
            
            # Check if position is valid
            occupied_positions = set()  # Simplified for random generation
            if is_position_valid(x, y, obj_type, occupied_positions, self.grid_width, self.grid_height):
                return {'type': obj_type, 'x': x, 'y': y}
        
        # Fallback to origin if no valid position found
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
            max_attempts = 500  # Increase attempts even more for desk
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
                elif attempt % 100 == 0:  # Log every 100th attempt
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
        
        # Randomly adjust position
        x, y = placement['x'], placement['y']
        obj_type = placement['type']
        
        # Get object dimensions for bounds checking
        obj_width, obj_height = get_object_grid_dimensions(obj_type)
        
        # Small random adjustment
        dx = random.randint(-3, 3)
        dy = random.randint(-3, 3)
        
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
                return False
            
            if check_object_collision(x, y, obj_type, occupied_positions):
                return False
            
            add_occupied_positions(x, y, obj_type, occupied_positions)
        
        return True
    
    def optimize_layout(self, objects_to_place: List[str]) -> Tuple[List[Dict], float]:
        """
        Optimize furniture layout using hill-climbing with Feng Shui principles.
        
        Args:
            objects_to_place: List of object types to place
            
        Returns:
            Tuple of (optimized_placements, final_score)
        """
        print(f"Starting Feng Shui optimization for {len(objects_to_place)} objects...")
        
        # Generate initial layout
        current_layout = self._generate_initial_layout(objects_to_place)
        current_score = self._calculate_layout_score(current_layout)
        
        best_layout = current_layout.copy()
        best_score = current_score
        
        print(f"Initial score: {current_score:.2f}")
        
        # Hill-climbing with simulated annealing
        temperature = self.config['algorithm']['temperature']
        no_improvement_count = 0
        
        for iteration in range(self.config['algorithm']['max_iterations']):
            # Create a mutated version of the current layout
            new_layout = []
            for placement in current_layout:
                if random.random() < self.config['algorithm']['mutation_rate']:
                    new_placement = self._mutate_placement(placement)
                    new_layout.append(new_placement)
                else:
                    new_layout.append(placement.copy())
            
            # Ensure layout is valid and contains all objects
            if not self._is_valid_layout(new_layout) or len(new_layout) != len(objects_to_place):
                continue
            
            # Calculate new score
            new_score = self._calculate_layout_score(new_layout)
            
            # Accept better solutions or worse solutions with probability (simulated annealing)
            if new_score > current_score or random.random() < math.exp((new_score - current_score) / temperature):
                current_layout = new_layout
                current_score = new_score
                
                # Update best solution
                if new_score > best_score:
                    best_layout = new_layout.copy()
                    best_score = new_score
                    no_improvement_count = 0
                    print(f"Iteration {iteration}: New best score: {best_score:.2f}")
                else:
                    no_improvement_count += 1
            else:
                no_improvement_count += 1
            
            # Cool down temperature
            temperature *= self.config['algorithm']['cooling_rate']
            
            # Early stopping if no improvement
            if no_improvement_count >= self.config['algorithm']['max_no_improvement']:
                print(f"Stopping early after {iteration} iterations (no improvement)")
                break
        
        # Ensure we return all objects
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
    
    if analysis['recommendations']:
        print(f"\nRecommendations:")
        for rec in analysis['recommendations']:
            print(f"  - {rec}") 
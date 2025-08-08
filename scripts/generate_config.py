#!/usr/bin/env python3
"""
Script to generate object configuration JSON from Flutter constants.
This ensures both Flutter and Python use the same object definitions.
"""

import json
import os

def generate_object_config():
    """Generate object configuration JSON from Flutter constants"""
    
    # This should match the Flutter ObjectConfig.dimensions
    objects = {
        "bed": {
            "width": 80,
            "height": 60,
            "icon": "bed",
            "type": "furniture"
        },
        "desk": {
            "width": 48,
            "height": 24,
            "icon": "desk",
            "type": "furniture"
        },
        "door": {
            "width": 30,
            "height": 0,
            "icon": "door_front_door",
            "type": "boundary"
        },
        "window": {
            "width": 24,
            "height": 0,
            "icon": "window",
            "type": "boundary"
        }
    }
    
    config = {
        "objects": objects,
        "grid_cell_size": 12,
        "units": "inches"
    }
    
    # Write to config file
    config_dir = os.path.join(os.path.dirname(__file__), '..', 'config')
    os.makedirs(config_dir, exist_ok=True)
    
    config_path = os.path.join(config_dir, 'objects.json')
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"Generated object configuration at: {config_path}")
    print(f"Objects defined: {list(objects.keys())}")

if __name__ == '__main__':
    generate_object_config() 
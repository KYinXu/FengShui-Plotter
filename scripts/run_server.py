#!/usr/bin/env python3
"""
Simple script to run the Flask server for live Feng Shui scoring.
"""

from app import app

if __name__ == '__main__':
    print("Starting Feng Shui Scoring Server...")
    print("Server will be available at: http://localhost:5000")
    print("Endpoints:")
    print("  - POST /calculate-live-score")
    print("  - POST /random-auto-placer")
    print("\nPress Ctrl+C to stop the server")
    
    app.run(debug=True, port=5000, host='0.0.0.0') 
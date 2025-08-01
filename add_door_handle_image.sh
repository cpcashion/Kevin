#!/bin/bash

# Script to add the door handle image to the app
# Usage: ./add_door_handle_image.sh path/to/your/door-handle-image.jpg

if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-door-handle-image>"
    echo "Example: $0 ~/Downloads/door-handle.jpg"
    exit 1
fi

IMAGE_PATH="$1"
DEST_DIR="/Users/cash/Library/Mobile Documents/com~apple~CloudDocs/Kevin/Kevin/KevinMaint/Assets.xcassets/demo-door-handle.imageset"
DEST_FILE="$DEST_DIR/demo-door-handle.jpg"

# Check if source image exists
if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: Image file not found: $IMAGE_PATH"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy the image
cp "$IMAGE_PATH" "$DEST_FILE"

echo "✅ Door handle image added successfully!"
echo "📍 Location: $DEST_FILE"
echo "🔄 Rebuild the app to see the real photo in the demo"

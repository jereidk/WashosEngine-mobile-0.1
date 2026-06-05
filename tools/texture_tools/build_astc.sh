#!/bin/bash
# ASTC Texture Build Script for WashosEngine
# Run this before building for Android to pre-compress textures

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NDK_PATH="${ANDROID_NDK_ROOT:-${HOME}/android-sdk/ndk/26.1.10909125}"
ASTC_BLOCK_SIZE="${ASTC_BLOCK_SIZE:-6x6}"
ASTC_QUALITY="${ASTC_QUALITY:-medium}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== WashosEngine ASTC Texture Converter ===${NC}"
echo "Block size: $ASTC_BLOCK_SIZE"
echo "Quality: $ASTC_QUALITY"
echo ""

# Check for astcenc
ASTCENC="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"
if [ ! -f "$ASTCENC" ]; then
    echo -e "${RED}Error: astcenc not found at $ASTCENC${NC}"
    echo "Please set ANDROID_NDK_ROOT or install Android NDK"
    exit 1
fi

echo -e "${GREEN}Found astcenc: $ASTCENC${NC}"

# Create output directories
ASSETS_DIR="$PROJECT_DIR/assets"
ASTC_OUTPUT="$PROJECT_DIR/assets-astc"

mkdir -p "$ASTC_OUTPUT"

# Function to convert a single image
convert_image() {
    local input="$1"
    local output="$2"
    
    "$ASTCENC" "$input" "$output" "$ASTC_BLOCK_SIZE" "$ASTC_QUALITY" -quiet 2>/dev/null
    if [ $? -eq 0 ]; then
        local orig_size=$(stat -c%s "$input" 2>/dev/null || echo "0")
        local astc_size=$(stat -c%s "$output" 2>/dev/null || echo "0")
        if [ "$orig_size" -gt 0 ]; then
            local ratio=$(echo "scale=1; (1 - $astc_size / $orig_size) * 100" | bc)
            echo "  ✓ $(basename "$input"): ${orig_size}B → ${astc_size}B (${ratio}% smaller)"
        fi
        return 0
    else
        echo "  ✗ Failed: $(basename "$input")"
        return 1
    fi
}

# Convert all PNG files recursively
echo "Converting textures..."
find "$ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | while read -r file; do
    # Calculate relative path
    rel_path="${file#$ASSETS_DIR/}"
    output_file="$ASTC_OUTPUT/$rel_path.astc"
    output_dir="$(dirname "$output_file")"
    
    mkdir -p "$output_dir"
    
    # Convert
    convert_image "$file" "$output_file" || true
done

echo ""
echo -e "${GREEN}ASTC texture conversion complete!${NC}"
echo "Output: $ASTC_OUTPUT"
echo ""
echo "To use ASTC textures in your build:"
echo "  1. Copy contents of $ASTC_OUTPUT to your Android assets folder"
echo "  2. Or update your build script to copy .astc files alongside .png"
echo ""
echo "Or run with Lime:"
echo "  lime build android -release"
echo "  # The build script will automatically copy .astc files if they exist"
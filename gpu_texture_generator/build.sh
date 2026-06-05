#!/bin/bash
# GPU Texture Generator - Build Integration Script
# Run this to generate GPU textures before building for Android

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NDK_PATH="${ANDROID_NDK_ROOT:-${HOME}/android-sdk/ndk/latest}"
ASTC_FORMAT="${ASTC_FORMAT:-ASTC}"
ASTC_BLOCK_SIZE="${ASTC_BLOCK_SIZE:-6x6}"
ASTC_QUALITY="${ASTC_QUALITY:-medium}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   WashosEngine GPU Texture Generator         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check for astcenc
ASTCENC="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc"
if [ ! -f "$ASTCENC" ]; then
    echo -e "${RED}Error: astcenc not found at $ASTCENC${NC}"
    echo "Please set ANDROID_NDK_ROOT environment variable"
    echo ""
    echo "Download Android NDK from:"
    echo "  https://developer.android.com/ndk/downloads"
    exit 1
fi

echo -e "${GREEN}✓ Found astcenc: $ASTCENC${NC}"
echo ""

# Create output directories
ASSETS_DIR="$PROJECT_DIR/assets"
COMPRESSED_OUTPUT="$PROJECT_DIR/assets/images-compressed"
BASE_OUTPUT="$PROJECT_DIR/assets/images-base"

mkdir -p "$COMPRESSED_OUTPUT"

# Function to convert a single image
convert_image() {
    local input="$1"
    local output="$2"
    local block_size="${3:-6x6}"
    local quality="${4:-medium}"
    
    local quality_flag="-medium"
    case "$quality" in
        fast) quality_flag="-fast" ;;
        thorough) quality_flag="-thorough" ;;
        exhaustive) quality_flag="-exhaustive" ;;
    esac
    
    "$ASTCENC" "$input" "$output" "$block_size" "$quality_flag" -quiet 2>/dev/null
    return $?
}

# Load configuration if exists
CONFIG_FILE="$PROJECT_DIR/astc-compression-data.json"
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Loading configuration from $CONFIG_FILE${NC}"
    # Parse JSON (requires jq, fallback to defaults if not available)
    if command -v jq &> /dev/null; then
        BLOCK_SIZE=$(jq -r '.defaultSettings.blockSize // "6x6"' "$CONFIG_FILE" 2>/dev/null || echo "6x6")
        QUALITY=$(jq -r '.defaultSettings.quality // "medium"' "$CONFIG_FILE" 2>/dev/null || echo "medium")
        ASTC_BLOCK_SIZE="${BLOCK_SIZE:-$ASTC_BLOCK_SIZE}"
        ASTC_QUALITY="${QUALITY:-$ASTC_QUALITY}"
    fi
fi

echo "Configuration:"
echo "  Format: $ASTC_FORMAT"
echo "  Block Size: $ASTC_BLOCK_SIZE"
echo "  Quality: $ASTC_QUALITY"
echo ""

# Find all PNG files
echo -e "${YELLOW}Scanning for textures...${NC}"
IMAGE_COUNT=$(find "$ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) 2>/dev/null | wc -l)
echo "Found $IMAGE_COUNT texture files"
echo ""

# Skip patterns from config
SKIP_PATTERNS=("fonts" "music" "sounds" "videos")
if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
    SKIP_JSON=$(jq -r '.defaultSettings.ignorePatterns // [] | join(" ")' "$CONFIG_FILE" 2>/dev/null || echo "")
fi

# Convert textures
echo -e "${YELLOW}Converting textures to $ASTC_FORMAT...${NC}"
SUCCESS=0
FAILED=0

while IFS= read -r file; do
    # Check skip patterns
    SKIP=false
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if [[ "$file" == *"$pattern"* ]]; then
            SKIP=true
            break
        fi
    done
    [ "$SKIP" = true ] && continue
    
    # Calculate relative path
    rel_path="${file#$ASSETS_DIR/}"
    output_file="$COMPRESSED_OUTPUT/$rel_path.astc"
    output_dir="$(dirname "$output_file")"
    
    mkdir -p "$output_dir"
    
    # Convert
    if convert_image "$file" "$output_file" "$ASTC_BLOCK_SIZE" "$ASTC_QUALITY"; then
        orig_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        astc_size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
        if [ "$orig_size" -gt 0 ]; then
            ratio=$(echo "scale=1; (1 - $astc_size / $orig_size) * 100" | bc)
            echo -e "  ${GREEN}✓${NC} $(basename "$file"): ${orig_size}B → ${astc_size}B (${ratio}% smaller)"
        fi
        ((SUCCESS++))
    else
        echo -e "  ${RED}✗${NC} Failed: $(basename "$file")"
        ((FAILED++))
    fi
done < <(find "$ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) 2>/dev/null)

echo ""
echo -e "${GREEN}Conversion complete!${NC}"
echo "  Success: $SUCCESS"
echo "  Failed: $FAILED"
echo ""

# Generate manifest
echo -e "${YELLOW}Generating manifest...${NC}"
MANIFEST_FILE="$COMPRESSED_OUTPUT/astc_manifest.json"
echo "{" > "$MANIFEST_FILE"
echo '  "version": "1.0.0",' >> "$MANIFEST_FILE"
echo '  "engine": "WashosEngine",' >> "$MANIFEST_FILE"
echo '  "format": "ASTC",' >> "$MANIFEST_FILE"
echo '  "textures": [' >> "$MANIFEST_FILE"

FIRST=true
while IFS= read -r file; do
    rel_path="${file#$ASSETS_DIR/}"
    astc_file="$COMPRESSED_OUTPUT/$rel_path.astc"
    [ ! -f "$astc_file" ] && continue
    
    size=$(stat -c%s "$astc_file" 2>/dev/null || echo "0")
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "$MANIFEST_FILE"
    fi
    
    echo -n '    {"path": "'"$rel_path.astc"'", "size": '"$size"', "format": "ASTC"}' >> "$MANIFEST_FILE"
done < <(find "$ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) 2>/dev/null)

echo "" >> "$MANIFEST_FILE"
echo "  ]" >> "$MANIFEST_FILE"
echo "}" >> "$MANIFEST_FILE"

echo -e "${GREEN}Manifest generated: $MANIFEST_FILE${NC}"
echo ""

# Summary
TOTAL_ORIG=0
TOTAL_ASTC=0

while IFS= read -r file; do
    rel_path="${file#$ASSETS_DIR/}"
    astc_file="$COMPRESSED_OUTPUT/$rel_path.astc"
    [ -f "$astc_file" ] && [ -f "$file" ] && {
        TOTAL_ORIG=$((TOTAL_ORIG + $(stat -c%s "$file" 2>/dev/null || echo "0")))
        TOTAL_ASTC=$((TOTAL_ASTC + $(stat -c%s "$astc_file" 2>/dev/null || echo "0")))
    }
done < <(find "$ASSETS_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) 2>/dev/null)

SAVINGS=$(echo "scale=1; (1 - $TOTAL_ASTC / $TOTAL_ORIG) * 100" | bc 2>/dev/null || echo "0")

echo "=========================================="
echo -e "${BLUE}Summary:${NC}"
echo "  Original size: $((TOTAL_ORIG / 1024))KB"
echo "  ASTC size: $((TOTAL_ASTC / 1024))KB"
echo "  Space saved: ${SAVINGS}%"
echo "  Output: $COMPRESSED_OUTPUT"
echo "=========================================="
echo ""
echo -e "${GREEN}GPU texture generation complete!${NC}"
echo ""
echo "To build with ASTC textures:"
echo "  1. Copy contents of $COMPRESSED_OUTPUT to your Android assets folder"
echo "  2. Or set ANDROID_ASSETS_PATH=$COMPRESSED_OUTPUT when building"
echo ""
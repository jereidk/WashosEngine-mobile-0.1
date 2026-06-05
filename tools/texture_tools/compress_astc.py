#!/usr/bin/env python3
"""
ASTC Texture Converter for WashosEngine
Converts PNG/JPG images to ASTC compressed format for Android.

Usage:
    python compress_astc.py [--input <folder>] [--output <folder>] [--block-size <WxH>] [--quality <0-100>]

Requirements:
    - Android NDK installed (for astcenc tool)
    - Python 3.6+
    - Pillow (pip install pillow)

Example:
    python compress_astc.py --input assets/images --output assets/images_astc
"""

import os
import sys
import argparse
import subprocess
import shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Default settings
DEFAULT_BLOCK_SIZE = "6x6"  # 6x6 offers good balance of quality and compression
DEFAULT_QUALITY = "medium"  # Options: fast, medium, thorough, exhaustive
SUPPORTED_FORMATS = ['.png', '.jpg', '.jpeg', '.bmp', '.tga']

def find_astcenc(ndk_path=None):
    """Find the astcenc executable in Android NDK."""
    possible_paths = [
        # Default NDK location
        os.path.expanduser("~/android-sdk/ndk/latest/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android31-astcenc"),
        os.path.expanduser("~/android-sdk/ndk/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android31-astcenc"),
        # Common locations
        "/opt/android-sdk/ndk/latest/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc",
        "/usr/local/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc",
    ]
    
    if ndk_path:
        possible_paths.insert(0, f"{ndk_path}/toolchains/llvm/prebuilt/linux-x86_64/bin/astcenc")
    
    for path in possible_paths:
        if os.path.exists(path):
            return path
    
    # Try to find in PATH
    result = shutil.which("astcenc")
    if result:
        return result
    
    return None

def convert_image_to_astc(input_path, output_path, block_size=DEFAULT_BLOCK_SIZE, quality=DEFAULT_QUALITY):
    """Convert a single image to ASTC format."""
    try:
        astcenc = find_astcenc()
        if not astcenc:
            logger.warning(f"astcenc not found, skipping {input_path}")
            return False
        
        # Build command
        cmd = [
            astcenc,
            input_path,
            output_path,
            block_size,
            quality,
            "-quiet"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            size_orig = os.path.getsize(input_path)
            size_astc = os.path.getsize(output_path)
            ratio = (1 - size_astc / size_orig) * 100 if size_orig > 0 else 0
            logger.info(f"✓ {Path(input_path).name}: {size_orig/1024:.1f}KB → {size_astc/1024:.1f}KB ({ratio:.1f}% smaller)")
            return True
        else:
            logger.error(f"✗ {input_path}: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"✗ {input_path}: {str(e)}")
        return False

def process_directory(input_dir, output_dir, block_size=DEFAULT_BLOCK_SIZE, quality=DEFAULT_QUALITY, workers=4):
    """Process all images in a directory tree."""
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    
    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Find all images
    images = []
    for fmt in SUPPORTED_FORMATS:
        images.extend(input_path.rglob(f"*{fmt}"))
        images.extend(input_path.rglob(f"*{fmt.upper()}"))
    
    # Remove duplicates
    images = list(set(images))
    
    if not images:
        logger.warning(f"No images found in {input_dir}")
        return 0, 0
    
    logger.info(f"Found {len(images)} images to convert")
    logger.info(f"Block size: {block_size}, Quality: {quality}")
    logger.info(f"Output: {output_dir}")
    
    # Process images
    success = 0
    failed = 0
    
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {}
        
        for img_path in images:
            # Calculate relative path
            rel_path = img_path.relative_to(input_path)
            
            # Create output path with .astc extension
            astc_path = output_path / rel_path.parent / (rel_path.stem + '.astc')
            astc_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Submit task
            future = executor.submit(convert_image_to_astc, str(img_path), str(astc_path), block_size, quality)
            futures[future] = str(img_path)
        
        # Collect results
        for future in as_completed(futures):
            img_path = futures[future]
            try:
                if future.result():
                    success += 1
                else:
                    failed += 1
            except Exception as e:
                logger.error(f"✗ {img_path}: {str(e)}")
                failed += 1
    
    return success, failed

def main():
    parser = argparse.ArgumentParser(
        description='Convert images to ASTC format for Android',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Convert all images in a folder:
    python compress_astc.py -i assets/images -o assets/images_astc
    
  Use 8x8 block size (smaller files):
    python compress_astc.py -i assets/images -o assets/images_astc -b 8x8
    
  Use high quality:
    python compress_astc.py -i assets/images -o assets/images_astc -q thorough
    
  Use custom NDK path:
    python compress_astc.py -i assets/images -o assets/images_astc --ndk /path/to/ndk
        """
    )
    
    parser.add_argument('-i', '--input', required=True, help='Input directory containing PNG/JPG images')
    parser.add_argument('-o', '--output', required=True, help='Output directory for ASTC files')
    parser.add_argument('-b', '--block-size', default=DEFAULT_BLOCK_SIZE, 
                        help=f'Block size (e.g., 4x4, 5x5, 6x6, 8x8). Default: {DEFAULT_BLOCK_SIZE}')
    parser.add_argument('-q', '--quality', default=DEFAULT_QUALITY,
                        help='Quality: fast, medium, thorough, exhaustive. Default: medium')
    parser.add_argument('-w', '--workers', type=int, default=4,
                        help='Number of parallel workers. Default: 4')
    parser.add_argument('--ndk', help='Path to Android NDK')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.input):
        logger.error(f"Input directory not found: {args.input}")
        sys.exit(1)
    
    # Find astcenc
    astcenc = find_astcenc(args.ndk)
    if not astcenc:
        logger.error("astcenc not found! Please install Android NDK or add it to PATH.")
        logger.error("Download from: https://developer.android.com/ndk/downloads")
        sys.exit(1)
    
    logger.info(f"Using astcenc: {astcenc}")
    
    # Process
    success, failed = process_directory(
        args.input, 
        args.output, 
        args.block_size, 
        args.quality,
        args.workers
    )
    
    logger.info(f"\nDone! Converted: {success}, Failed: {failed}")
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main() or 0)
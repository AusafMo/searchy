import torch
from PIL import Image
import os
import pickle
import numpy as np
from tqdm import tqdm
from transformers import CLIPProcessor, CLIPModel
import sys
import json
import argparse
import re
import time

# Global model cache to avoid reloading
_model = None
_processor = None
_device = None

def get_device():
    """Get the best available device (MPS for Apple Silicon, CUDA, or CPU)"""
    global _device
    if _device is None:
        if torch.backends.mps.is_available():
            _device = torch.device("mps")
            print(f"🚀 Using Apple Metal (MPS) acceleration", file=sys.stderr)
        elif torch.cuda.is_available():
            _device = torch.device("cuda")
            print(f"🚀 Using CUDA GPU acceleration", file=sys.stderr)
        else:
            _device = torch.device("cpu")
            print(f"💻 Using CPU (no GPU acceleration available)", file=sys.stderr)
    return _device

def get_model_and_processor():
    """Get or load CLIP model (singleton pattern) with GPU support"""
    global _model, _processor
    if _model is None or _processor is None:
        model_name = "openai/clip-vit-base-patch32"
        print(f"Loading {model_name}...", file=sys.stderr)
        _model = CLIPModel.from_pretrained(model_name, token=False)
        _processor = CLIPProcessor.from_pretrained(model_name, token=False)

        # Move model to GPU if available
        device = get_device()
        _model = _model.to(device)

        print(f"✅ Successfully loaded {model_name} on {device}", file=sys.stderr)
    return _model, _processor

def resize_image_for_fast_indexing(image, max_dimension=384):
    """Resize image to max dimension while preserving aspect ratio"""
    width, height = image.size
    if width <= max_dimension and height <= max_dimension:
        return image

    if width > height:
        new_width = max_dimension
        new_height = int(height * (max_dimension / width))
    else:
        new_height = max_dimension
        new_width = int(width * (max_dimension / height))

    return image.resize((new_width, new_height), Image.LANCZOS)

def matches_filter(filename, filter_type, filter_value):
    """Check if filename matches the filter criteria"""
    if not filter_value or filter_type == "all":
        return True

    filename_lower = filename.lower()
    filter_lower = filter_value.lower()

    if filter_type == "starts-with":
        return filename_lower.startswith(filter_lower)
    elif filter_type == "ends-with":
        return filename_lower.endswith(filter_lower)
    elif filter_type == "contains":
        return filter_lower in filename_lower
    elif filter_type == "regex":
        try:
            return bool(re.search(filter_value, filename, re.IGNORECASE))
        except re.error:
            return False
    return True

def index_images_with_clip(output_dir, incremental=False, new_files=None,
                           fast_indexing=True, max_dimension=384, batch_size=64,
                           filter_type=None, filter_value=None):
    """
    Index images with CLIP embeddings

    Args:
        output_dir: Directory to save the index
        incremental: If True, only index new_files (for auto-indexing)
        new_files: List of specific files to index (for incremental indexing)
        fast_indexing: If True, resize images before processing
        max_dimension: Maximum dimension for fast indexing
        batch_size: Number of images to process at once
        filter_type: Type of filename filter
        filter_value: Value for the filter
    """
    output_file = os.path.join(output_dir, 'image_index.bin')

    # Load existing index
    existing_embeddings = []
    existing_paths = []
    if os.path.exists(output_file):
        print("Loading existing index...", file=sys.stderr)
        with open(output_file, 'rb') as f:
            data = pickle.load(f)
            existing_embeddings = data['embeddings'].tolist()
            existing_paths = data['image_paths']
            print(f"Loaded {len(existing_paths)} existing images", file=sys.stderr)

    # Get CLIP model
    model, processor = get_model_and_processor()
    device = get_device()

    # Directories to skip (system, packages, caches, etc.)
    skip_dirs = {
        'site-packages', 'node_modules', 'vendor', '__pycache__',
        'env', 'venv', '.venv', 'virtualenv',
        'Library', 'Caches', 'cache', '.cache',
        'build', 'dist', 'target', '.git', '.svn',
        'DerivedData', 'xcuserdata', 'Pods',
        '__MACOSX', '.Trash', '.Spotlight-V100', '.fseventsd'
    }

    def is_user_image(path):
        if os.path.basename(path).startswith('.'):
            return False
        parts = path.split(os.sep)
        return not any(part in skip_dirs for part in parts)

    # Filter out hidden, system, and package files (handle None)
    if new_files is None:
        new_files = []
    new_files = [f for f in new_files if is_user_image(f)]

    if filter_type and filter_value:
        new_files = [f for f in new_files if matches_filter(os.path.basename(f), filter_type, filter_value)]
        print(f"After filtering: {len(new_files)} files match '{filter_type}: {filter_value}'", file=sys.stderr)

    # Process new files in batches
    embeddings = []
    valid_paths = []

    # Filter out already indexed files
    files_to_process = [f for f in new_files if f not in existing_paths and os.path.exists(f)]

    if not files_to_process:
        print("No new images to index", file=sys.stderr)
        return

    print(f"Processing {len(files_to_process)} new images (batch_size={batch_size}, fast={fast_indexing}, max_dim={max_dimension})", file=sys.stderr)

    # Process in batches
    for i in range(0, len(files_to_process), batch_size):
        batch_files = files_to_process[i:i + batch_size]
        batch_images = []
        batch_paths = []

        for img_path in batch_files:
            try:
                image = Image.open(img_path)
                if image.mode != 'RGB':
                    image = image.convert('RGB')

                # Apply fast indexing resize if enabled
                if fast_indexing:
                    image = resize_image_for_fast_indexing(image, max_dimension)

                batch_images.append(image)
                batch_paths.append(img_path)
            except Exception as e:
                print(f"❌ Error loading {img_path}: {e}", file=sys.stderr)
                continue

        if not batch_images:
            continue

        try:
            # Process batch
            inputs = processor(images=batch_images, return_tensors="pt", padding=True)
            inputs = {k: v.to(device) for k, v in inputs.items()}

            with torch.no_grad():
                image_features = model.get_image_features(**inputs)

            # Normalize embeddings
            batch_embeddings = image_features.cpu().numpy()
            batch_embeddings = batch_embeddings / np.linalg.norm(batch_embeddings, axis=1, keepdims=True)

            embeddings.extend(batch_embeddings.tolist())
            valid_paths.extend(batch_paths)

            print(f"✅ Processed batch {i//batch_size + 1}: {len(batch_paths)} images", file=sys.stderr)

        except Exception as e:
            print(f"❌ Error processing batch: {e}", file=sys.stderr)
            # Fall back to processing one by one
            for img, path in zip(batch_images, batch_paths):
                try:
                    inputs = processor(images=img, return_tensors="pt")
                    inputs = {k: v.to(device) for k, v in inputs.items()}
                    with torch.no_grad():
                        features = model.get_image_features(**inputs)
                    embedding = features.cpu().numpy()[0]
                    embedding = embedding / np.linalg.norm(embedding)
                    embeddings.append(embedding)
                    valid_paths.append(path)
                except Exception as e2:
                    print(f"❌ Error processing {path}: {e2}", file=sys.stderr)

    if not embeddings:
        print("No new images were successfully processed", file=sys.stderr)
        return

    # Merge with existing
    all_embeddings = existing_embeddings + embeddings
    all_paths = existing_paths + valid_paths
    all_embeddings = np.array(all_embeddings)

    # Save updated index
    os.makedirs(output_dir, exist_ok=True)
    data = {
        'embeddings': all_embeddings,
        'image_paths': all_paths
    }

    with open(output_file, 'wb') as f:
        pickle.dump(data, f)

    print(f"✅ Index updated: {len(all_paths)} total images (+{len(valid_paths)} new)", file=sys.stderr)

def process_images(image_dir, output_dir, fast_indexing=True, max_dimension=384,
                   batch_size=64, filter_type=None, filter_value=None):
    """Process all images in a directory"""
    try:
        output_file = os.path.join(output_dir, 'image_index.bin')
        existing_embeddings = []
        existing_paths = []
        if os.path.exists(output_file):
            print("Loading existing index...", file=sys.stderr)
            with open(output_file, 'rb') as f:
                data = pickle.load(f)
                existing_embeddings = data['embeddings'].tolist()
                existing_paths = data['image_paths']
                print(f"Loaded {len(existing_paths)} existing images", file=sys.stderr)

        print("Loading CLIP model...", file=sys.stderr)
        model, processor = get_model_and_processor()
        device = get_device()

        print(f"Scanning for images in {image_dir}...", file=sys.stderr)
        image_paths = []

        # Directories to skip (system, packages, caches, etc.)
        skip_dirs = {
            'site-packages', 'node_modules', 'vendor', '__pycache__',
            'env', 'venv', '.venv', 'virtualenv',
            'Library', 'Caches', 'cache', '.cache',
            'build', 'dist', 'target', '.git', '.svn',
            'DerivedData', 'xcuserdata', 'Pods',
            '__MACOSX', '.Trash', '.Spotlight-V100', '.fseventsd'
        }

        for root, dirs, files in os.walk(image_dir):
            # Skip hidden directories and system directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in skip_dirs]

            for file in files:
                # Skip hidden and macOS metadata files
                if file.startswith('.'):
                    continue

                if file.lower().endswith(('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp')):
                    # Apply filter if specified
                    if filter_type and filter_value:
                        if not matches_filter(file, filter_type, filter_value):
                            continue

                    full_path = os.path.join(root, file)
                    if full_path not in existing_paths:
                        image_paths.append(full_path)
                    else:
                        print(f"Skipping already indexed: {file}", file=sys.stderr)

        if not image_paths:
            print(f"No new images found in {image_dir}", file=sys.stderr)
            return

        total_images = len(image_paths)
        total_batches = (total_images + batch_size - 1) // batch_size
        print(f"Found {total_images} new images. Processing with batch_size={batch_size}...", file=sys.stderr)

        # Output initial progress
        print(json.dumps({"type": "start", "total_images": total_images, "total_batches": total_batches}), flush=True)

        # Create empty index file immediately if none exists (so search works during indexing)
        if not os.path.exists(output_file):
            os.makedirs(output_dir, exist_ok=True)
            empty_data = {
                'embeddings': np.array([]).reshape(0, 512),  # Empty array with correct shape
                'image_paths': []
            }
            with open(output_file, 'wb') as f:
                pickle.dump(empty_data, f)
            print("Created initial empty index file", file=sys.stderr)

        embeddings = []
        valid_paths = []
        start_time = time.time()

        # Process in batches
        for i in range(0, total_images, batch_size):
            batch_files = image_paths[i:i + batch_size]
            batch_images = []
            batch_paths = []

            for img_path in batch_files:
                try:
                    image = Image.open(img_path)
                    if image.mode != 'RGB':
                        image = image.convert('RGB')

                    # Apply fast indexing resize if enabled
                    if fast_indexing:
                        image = resize_image_for_fast_indexing(image, max_dimension)

                    batch_images.append(image)
                    batch_paths.append(img_path)
                except Exception as e:
                    print(f"❌ Error loading {img_path}: {e}", file=sys.stderr)
                    continue

            if not batch_images:
                continue

            try:
                # Process batch with GPU
                inputs = processor(images=batch_images, return_tensors="pt", padding=True)
                inputs = {k: v.to(device) for k, v in inputs.items()}

                with torch.no_grad():
                    image_features = model.get_image_features(**inputs)

                # Normalize embeddings
                batch_embeddings = image_features.cpu().numpy()
                batch_embeddings = batch_embeddings / np.linalg.norm(batch_embeddings, axis=1, keepdims=True)

                embeddings.extend(batch_embeddings.tolist())
                valid_paths.extend(batch_paths)

                batch_num = i // batch_size + 1
                elapsed = time.time() - start_time
                images_per_sec = len(valid_paths) / elapsed if elapsed > 0 else 0

                # Save incrementally after each batch (allows searching while indexing)
                current_all_embeddings = existing_embeddings + embeddings
                current_all_paths = existing_paths + valid_paths
                current_all_embeddings_np = np.array(current_all_embeddings)

                os.makedirs(output_dir, exist_ok=True)
                temp_data = {
                    'embeddings': current_all_embeddings_np,
                    'image_paths': current_all_paths
                }
                with open(output_file, 'wb') as f:
                    pickle.dump(temp_data, f)

                print(json.dumps({
                    "type": "progress",
                    "batch": batch_num,
                    "total_batches": total_batches,
                    "images_processed": len(valid_paths),
                    "total_images": total_images,
                    "elapsed": round(elapsed, 2),
                    "images_per_sec": round(images_per_sec, 1),
                    "indexed_total": len(current_all_paths)
                }), flush=True)
                print(f"✅ Batch {batch_num}/{total_batches}: {len(batch_paths)} images (index saved)", file=sys.stderr)

            except Exception as e:
                print(f"❌ Batch error, falling back to single processing: {e}", file=sys.stderr)
                # Fall back to single image processing
                for img, path in zip(batch_images, batch_paths):
                    try:
                        inputs = processor(images=img, return_tensors="pt")
                        inputs = {k: v.to(device) for k, v in inputs.items()}
                        with torch.no_grad():
                            features = model.get_image_features(**inputs)
                        embedding = features.cpu().numpy()[0]
                        embedding = embedding / np.linalg.norm(embedding)
                        embeddings.append(embedding)
                        valid_paths.append(path)
                    except Exception as e2:
                        print(f"❌ Error: {path}: {e2}", file=sys.stderr)

        if not embeddings:
            print("No valid images were processed", file=sys.stderr)
            return

        # Merge with existing
        all_embeddings = existing_embeddings + embeddings
        all_paths = existing_paths + valid_paths
        all_embeddings = np.array(all_embeddings)

        # Save
        os.makedirs(output_dir, exist_ok=True)
        data = {
            'embeddings': all_embeddings,
            'image_paths': all_paths
        }

        with open(output_file, 'wb') as f:
            pickle.dump(data, f)

        total_time = time.time() - start_time
        images_per_sec = len(valid_paths) / total_time if total_time > 0 else 0

        # Output completion report as JSON
        print(json.dumps({
            "type": "complete",
            "total_images": len(all_paths),
            "new_images": len(valid_paths),
            "total_time": round(total_time, 2),
            "images_per_sec": round(images_per_sec, 1)
        }), flush=True)

        print(f"✅ Total images in index: {len(all_paths)}", file=sys.stderr)
        print(f"✅ New images added: {len(valid_paths)}", file=sys.stderr)
        print(f"✅ Embeddings shape: {all_embeddings.shape}", file=sys.stderr)
        print(f"✅ Saved to {output_file}", file=sys.stderr)

    except Exception as e:
        print(f"❌ Failed to process images: {str(e)}", file=sys.stderr)
        import traceback
        print(traceback.format_exc(), file=sys.stderr)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate CLIP embeddings for images")
    parser.add_argument("image_dir", help="Directory containing images to index")
    parser.add_argument("--output-dir", default="/Users/ausaf/Library/Application Support/searchy",
                        help="Directory to save the index")
    parser.add_argument("--fast", action="store_true", default=True,
                        help="Enable fast indexing (resize images)")
    parser.add_argument("--no-fast", action="store_false", dest="fast",
                        help="Disable fast indexing")
    parser.add_argument("--max-dimension", type=int, default=384,
                        help="Maximum image dimension for fast indexing (256, 384, 512, 768)")
    parser.add_argument("--batch-size", type=int, default=64,
                        help="Batch size for processing (32, 64, 128, 256)")
    parser.add_argument("--filter-type", type=str, default=None,
                        choices=["all", "starts-with", "ends-with", "contains", "regex"],
                        help="Type of filename filter")
    parser.add_argument("--filter", type=str, default=None,
                        help="Filter value for filename matching")

    args = parser.parse_args()

    if not os.path.exists(args.image_dir):
        print(f"Error: Directory '{args.image_dir}' does not exist", file=sys.stderr)
        sys.exit(1)

    process_images(
        args.image_dir,
        args.output_dir,
        fast_indexing=args.fast,
        max_dimension=args.max_dimension,
        batch_size=args.batch_size,
        filter_type=args.filter_type,
        filter_value=args.filter
    )

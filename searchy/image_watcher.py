#!/usr/bin/env python3
"""
Image Watcher - Monitors directories for new images and auto-indexes them
Supports filename filters and uses IndexingSettings from Swift app
"""
import os
import sys
import time
import json
import re
import argparse
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from generate_embeddings import index_images_with_clip, get_device

# Supported image extensions
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.heic'}

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

class ImageEventHandler(FileSystemEventHandler):
    def __init__(self, data_dir, filter_type=None, filter_value=None,
                 fast_indexing=True, max_dimension=384, batch_size=64):
        self.data_dir = data_dir
        self.filter_type = filter_type
        self.filter_value = filter_value
        self.fast_indexing = fast_indexing
        self.max_dimension = max_dimension
        self.batch_size = batch_size
        self.pending_files = set()
        self.last_index_time = time.time()
        self.debounce_delay = 2.0  # Wait 2 seconds before indexing

    def on_created(self, event):
        """Called when a file or directory is created"""
        if event.is_directory:
            return

        file_path = event.src_path
        if self._is_valid_image(file_path):
            print(f"📸 New image detected: {os.path.basename(file_path)}", file=sys.stderr)
            self.pending_files.add(file_path)
            self.last_index_time = time.time()

    def on_moved(self, event):
        """Called when a file or directory is moved"""
        if event.is_directory:
            return

        dest_path = event.dest_path
        if self._is_valid_image(dest_path):
            print(f"📸 Image moved/added: {os.path.basename(dest_path)}", file=sys.stderr)
            self.pending_files.add(dest_path)
            self.last_index_time = time.time()

    def _is_image(self, file_path):
        """Check if file is an image by extension"""
        filename = os.path.basename(file_path)
        # Skip macOS metadata files (AppleDouble resource forks)
        if filename.startswith('._'):
            return False
        ext = Path(file_path).suffix.lower()
        return ext in IMAGE_EXTENSIONS

    def _is_valid_image(self, file_path):
        """Check if file is an image AND matches the filter"""
        if not self._is_image(file_path):
            return False

        filename = os.path.basename(file_path)

        # Apply filter if set
        if self.filter_type and self.filter_value:
            if not matches_filter(filename, self.filter_type, self.filter_value):
                print(f"⏭️ Skipping (doesn't match filter): {filename}", file=sys.stderr)
                return False

        return True

    def check_and_index(self):
        """Check if we should index pending files"""
        if not self.pending_files:
            return

        # Debounce: wait until no new files for debounce_delay seconds
        time_since_last = time.time() - self.last_index_time
        if time_since_last >= self.debounce_delay:
            files_to_index = []

            # Verify files exist and are readable before indexing
            for file_path in list(self.pending_files):
                if os.path.exists(file_path):
                    try:
                        # Try to open the file to make sure it's complete and readable
                        with open(file_path, 'rb') as f:
                            f.read(1)  # Just read 1 byte to verify
                        files_to_index.append(file_path)
                    except Exception as e:
                        print(f"⚠️ File not ready yet, will retry: {os.path.basename(file_path)}", file=sys.stderr)
                        continue
                else:
                    print(f"⚠️ File disappeared: {os.path.basename(file_path)}", file=sys.stderr)

            # Clear all files from pending (including ones that weren't ready)
            self.pending_files.clear()

            if not files_to_index:
                return

            print(f"🔄 Auto-indexing {len(files_to_index)} new image(s)...", file=sys.stderr)
            print(f"   Settings: fast={self.fast_indexing}, max_dim={self.max_dimension}, batch={self.batch_size}", file=sys.stderr)

            # Index the new images with settings
            try:
                index_images_with_clip(
                    self.data_dir,
                    incremental=True,
                    new_files=files_to_index,
                    fast_indexing=self.fast_indexing,
                    max_dimension=self.max_dimension,
                    batch_size=self.batch_size
                )
                print(f"✅ Successfully indexed {len(files_to_index)} image(s)", file=sys.stderr)
            except Exception as e:
                print(f"❌ Error indexing images: {e}", file=sys.stderr)
                import traceback
                traceback.print_exc()


def watch_directory(watch_path, data_dir, filter_type=None, filter_value=None,
                    fast_indexing=True, max_dimension=384, batch_size=64):
    """Watch directory for new images and auto-index them"""
    # Initialize device early to show GPU status
    device = get_device()

    print(f"👀 Watching for new images in: {watch_path}", file=sys.stderr)
    print(f"📁 Index location: {data_dir}", file=sys.stderr)
    if filter_type and filter_value:
        print(f"🔍 Filter: {filter_type} = '{filter_value}'", file=sys.stderr)
    print(f"⚙️ Fast indexing: {fast_indexing}, Max dimension: {max_dimension}px, Batch size: {batch_size}", file=sys.stderr)

    event_handler = ImageEventHandler(
        data_dir,
        filter_type=filter_type,
        filter_value=filter_value,
        fast_indexing=fast_indexing,
        max_dimension=max_dimension,
        batch_size=batch_size
    )
    observer = Observer()
    observer.schedule(event_handler, watch_path, recursive=True)
    observer.start()

    try:
        while True:
            time.sleep(0.5)  # Check every 500ms
            event_handler.check_and_index()
    except KeyboardInterrupt:
        print("\n⏹️  Stopping image watcher...", file=sys.stderr)
        observer.stop()

    observer.join()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Watch directory for new images and auto-index")
    parser.add_argument("watch_dir", help="Directory to watch for new images")
    parser.add_argument("data_dir", help="Directory to store the index")
    parser.add_argument("--filter-type", type=str, default=None,
                        choices=["all", "starts-with", "ends-with", "contains", "regex"],
                        help="Type of filename filter")
    parser.add_argument("--filter", type=str, default=None,
                        help="Filter value for filename matching")
    parser.add_argument("--fast", action="store_true", default=True,
                        help="Enable fast indexing (resize images)")
    parser.add_argument("--no-fast", action="store_false", dest="fast",
                        help="Disable fast indexing")
    parser.add_argument("--max-dimension", type=int, default=384,
                        help="Maximum image dimension for fast indexing")
    parser.add_argument("--batch-size", type=int, default=64,
                        help="Batch size for processing")

    args = parser.parse_args()

    if not os.path.exists(args.watch_dir):
        print(f"❌ Watch directory does not exist: {args.watch_dir}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.data_dir, exist_ok=True)

    watch_directory(
        args.watch_dir,
        args.data_dir,
        filter_type=args.filter_type,
        filter_value=args.filter,
        fast_indexing=args.fast,
        max_dimension=args.max_dimension,
        batch_size=args.batch_size
    )

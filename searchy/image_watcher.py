#!/usr/bin/env python3
"""
Image Watcher - Monitors directories for new images and auto-indexes them
"""
import os
import sys
import time
import json
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from generate_embeddings import index_images_with_clip

# Supported image extensions
IMAGE_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.heic'}

class ImageEventHandler(FileSystemEventHandler):
    def __init__(self, data_dir):
        self.data_dir = data_dir
        self.pending_files = set()
        self.last_index_time = time.time()
        self.debounce_delay = 2.0  # Wait 2 seconds before indexing

    def on_created(self, event):
        """Called when a file or directory is created"""
        if event.is_directory:
            return

        file_path = event.src_path
        if self._is_image(file_path):
            print(f"📸 New image detected: {file_path}", file=sys.stderr)
            self.pending_files.add(file_path)
            self.last_index_time = time.time()

    def on_moved(self, event):
        """Called when a file or directory is moved"""
        if event.is_directory:
            return

        dest_path = event.dest_path
        if self._is_image(dest_path):
            print(f"📸 Image moved/added: {dest_path}", file=sys.stderr)
            self.pending_files.add(dest_path)
            self.last_index_time = time.time()

    def _is_image(self, file_path):
        """Check if file is an image"""
        ext = Path(file_path).suffix.lower()
        return ext in IMAGE_EXTENSIONS

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

            # Index the new images
            try:
                index_images_with_clip(self.data_dir, incremental=True, new_files=files_to_index)
                print(f"✅ Successfully indexed {len(files_to_index)} image(s)", file=sys.stderr)
            except Exception as e:
                print(f"❌ Error indexing images: {e}", file=sys.stderr)
                import traceback
                traceback.print_exc()


def watch_directory(watch_path, data_dir):
    """Watch directory for new images and auto-index them"""
    print(f"👀 Watching for new images in: {watch_path}", file=sys.stderr)
    print(f"📁 Index location: {data_dir}", file=sys.stderr)

    event_handler = ImageEventHandler(data_dir)
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
    if len(sys.argv) < 3:
        print("Usage: python3 image_watcher.py <watch_directory> <data_directory>")
        sys.exit(1)

    watch_dir = sys.argv[1]
    data_dir = sys.argv[2]

    if not os.path.exists(watch_dir):
        print(f"❌ Watch directory does not exist: {watch_dir}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    watch_directory(watch_dir, data_dir)

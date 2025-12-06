#!/usr/bin/env python3
"""Debug script to inspect the image index"""
import pickle
import os
from collections import Counter
from datetime import datetime

index_file = "/Users/ausaf/Library/Application Support/searchy/image_index.bin"

if os.path.exists(index_file):
    with open(index_file, 'rb') as f:
        data = pickle.load(f)

    image_paths = data['image_paths']
    print(f"Total images in index: {len(image_paths)}")
    print()

    # Group by directory
    dirs = [os.path.dirname(path) for path in image_paths]
    dir_counts = Counter(dirs)

    print("Images by directory:")
    for dir_path, count in dir_counts.most_common():
        print(f"  {dir_path}: {count} images")
    print()

    # Show 10 most recent by creation time
    print("10 Most recent images by creation time:")
    images_with_time = []
    for path in image_paths:
        if os.path.exists(path):
            try:
                stat_info = os.stat(path)
                creation_time = getattr(stat_info, 'st_birthtime', stat_info.st_ctime)
                images_with_time.append((path, creation_time))
            except:
                pass

    images_with_time.sort(key=lambda x: x[1], reverse=True)

    for path, ctime in images_with_time[:10]:
        dt = datetime.fromtimestamp(ctime)
        print(f"  {dt.strftime('%Y-%m-%d %H:%M:%S')} - {path}")
else:
    print(f"Index file not found: {index_file}")

#!/usr/bin/env python3
"""Check if there are screenshots in the index"""
import pickle
import os
from datetime import datetime

index_file = "/Users/ausaf/Library/Application Support/searchy/image_index.bin"

if os.path.exists(index_file):
    with open(index_file, 'rb') as f:
        data = pickle.load(f)

    image_paths = data['image_paths']

    # Find screenshots (files starting with "Screenshot")
    screenshots = [p for p in image_paths if os.path.basename(p).startswith("Screenshot")]

    print(f"Total screenshots in index: {len(screenshots)}")
    print()

    if screenshots:
        # Show 10 most recent screenshots
        print("10 Most recent screenshots:")
        screenshots_with_time = []
        for path in screenshots:
            if os.path.exists(path):
                try:
                    stat_info = os.stat(path)
                    creation_time = getattr(stat_info, 'st_birthtime', stat_info.st_ctime)
                    screenshots_with_time.append((path, creation_time))
                except:
                    pass

        screenshots_with_time.sort(key=lambda x: x[1], reverse=True)

        for path, ctime in screenshots_with_time[:10]:
            dt = datetime.fromtimestamp(ctime)
            print(f"  {dt.strftime('%Y-%m-%d %H:%M:%S')} - {path}")
    else:
        print("No screenshots found in index!")
        print()
        print("Desktop images in index:")
        desktop_images = [p for p in image_paths if p.startswith("/Users/ausaf/Desktop")]
        for img in desktop_images[:20]:
            print(f"  {img}")
else:
    print(f"Index file not found: {index_file}")

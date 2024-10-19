# TODO: This is not yet implemented and used, need to figure out how to run this in background cron without using much resources...

import os
import time
from PIL import Images
from embedding_utils import save_embeddings, load_embeddings
from clip_model import generate_image_embedding

# Path to store a record of the last time the folder was indexed
last_index_time_file = 'last_index_time.txt'

# List of folders to monitor for new images
folders_to_monitor = [
    '/path/to/folder1',
    '/path/to/folder2'
]

def get_last_index_time():
    if os.path.exists(last_index_time_file):
        with open(last_index_time_file, 'r') as f:
            return float(f.read().strip())
    return 0

def update_last_index_time():
    current_time = time.time()
    with open(last_index_time_file, 'w') as f:
        f.write(str(current_time))

def is_image_file(filename):
    return filename.lower().endswith(('.jpg', '.jpeg', '.png'))

def index_new_images():
    # Load existing embeddings and paths, if available
    embeddings, image_paths = load_embeddings('image_index.bin')
    if embeddings is None:
        embeddings = []
        image_paths = []

    last_index_time = get_last_index_time()

    new_embeddings = []
    new_image_paths = []

    for folder in folders_to_monitor:
        for root, dirs, files in os.walk(folder):
            for file in files:
                if is_image_file(file):
                    file_path = os.path.join(root, file)
                    file_mod_time = os.path.getmtime(file_path)

                    if file_mod_time > last_index_time:
                        try:
                            image = Image.open(file_path)
                            image_embedding = generate_image_embedding(image)
                            if image_embedding is not None:
                                new_embeddings.append(image_embedding)
                                new_image_paths.append(file_path)
                        except Exception as e:
                            print(f"Error processing {file_path}: {e}")

    if new_embeddings:
        embeddings.extend(new_embeddings)
        image_paths.extend(new_image_paths)

        save_embeddings(embeddings, image_paths)

        print(f"Indexed {len(new_embeddings)} new images.")
    else:
        print("No new images found.")

    update_last_index_time()

if __name__ == "__main__":
    index_new_images()

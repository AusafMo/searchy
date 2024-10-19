import os
import numpy as np  
from PIL import Image
from tqdm import tqdm
from clip_model import generate_image_embedding
from embedding_utils import save_embeddings, load_embeddings

def index_images_from_folder(folder_path):
    # Load existing embeddings and paths, if available
    existing_embeddings, existing_image_paths = load_embeddings('image_index.bin')
    
    if existing_embeddings is None:
        existing_embeddings = np.array([]).reshape(0, 512)
        existing_image_paths = []

    image_paths = [os.path.join(folder_path, fname) for fname in os.listdir(folder_path)
                   if fname.lower().endswith(('.jpg', '.jpeg', '.png'))]

    if not image_paths:
        print("No valid image files found in the folder.")
        return

    new_image_paths = [img_path for img_path in image_paths if img_path not in existing_image_paths]

    if not new_image_paths:
        print("No new images to index.")
        return

    embeddings = []
    valid_image_paths = []

    for img_path in tqdm(new_image_paths, desc="Processing new images"):
        try:

            image = Image.open(img_path)
            
            image_embedding = generate_image_embedding(image)

            if image_embedding is not None:
                embeddings.append(image_embedding)
                valid_image_paths.append(img_path)  # Store only valid image paths

        except Exception as e:
            print(f"Error processing image {img_path}: {e}")

    if embeddings:
        print(f"Successfully generated embeddings for {len(embeddings)} new images.")
        
        embeddings = np.array(embeddings)

        if existing_embeddings.size == 0:
            updated_embeddings = embeddings
        else:
            updated_embeddings = np.vstack((existing_embeddings, embeddings))

        updated_image_paths = existing_image_paths + valid_image_paths

        save_embeddings(updated_embeddings, updated_image_paths)
    else:
        print("No new embeddings were generated.")

if __name__ == "__main__":
    folder_path = input("Enter the path to the folder containing images: ").strip()
    index_images_from_folder(folder_path)

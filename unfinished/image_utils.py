import os
from PIL import Image, UnidentifiedImageError
from tqdm import tqdm
from clip_model import generate_image_embedding
import pickle

def load_image_paths(folder_path):
    try:
        if not os.path.exists(folder_path):
            raise FileNotFoundError(f"Folder '{folder_path}' does not exist.")
        
        image_paths = [os.path.join(folder_path, img) for img in os.listdir(folder_path) if img.endswith(('.jpg', '.png', '.jpeg'))]
        
        if not image_paths:
            raise ValueError(f"No valid images found in folder '{folder_path}'.")
        
        return image_paths
    except Exception as e:
        print(f"Error loading image paths: {e}")
        return []

def generate_image_embeddings(image_paths):
    embeddings = []
    for img_path in tqdm(image_paths, desc="Generating Image Embeddings"):
        try:
            image = Image.open(img_path)
            embedding = generate_image_embedding(image)
            if embedding is not None:
                embeddings.append(embedding)
            else:
                print(f"Failed to generate embedding for image {img_path}.")
        except UnidentifiedImageError:
            print(f"Unrecognized image format: {img_path}")
        except Exception as e:
            print(f"Error processing image {img_path}: {e}")
    
    if not embeddings:
        print("No valid image embeddings generated.")
    
    return embeddings

image_paths = load_image_paths('images')
image_embeddings = generate_image_embeddings(image_paths)
with open('image_index.bin', 'wb') as f:
    pickle.dump(image_embeddings, f)
print("Image embeddings saved to 'image_index.bin'.")

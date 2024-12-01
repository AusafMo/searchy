import torch
from PIL import Image
import os
import pickle
import numpy as np
from tqdm import tqdm
from transformers import CLIPProcessor, CLIPModel
import sys
import json

def process_images(image_dir, output_dir):
    try:
        
        output_file = os.path.join(output_dir, 'image_index.bin')
        existing_embeddings = []
        existing_paths = []
        if os.path.exists(output_file):
            print("Loading existing index...")
            with open(output_file, 'rb') as f:
                data = pickle.load(f)
                existing_embeddings = data['embeddings'].tolist()
                existing_paths = data['image_paths']
                print(f"Loaded {len(existing_paths)} existing images")

        print("Loading CLIP model...")
        model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
        
        print("Scanning for images...")
        image_paths = []
        for root, dirs, files in os.walk(image_dir):
            for file in files:
                if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                    
                    full_path = os.path.join(root, file)
                    if full_path not in existing_paths:
                        image_paths.append(full_path)
                    else:
                        print(f"Skipping already indexed image: {file}")
        
        if not image_paths:
            print(f"No new images found in {image_dir}")
            return
            
        total_images = len(image_paths)
        print(f"Found {total_images} new images. Processing...")
        
        embeddings = []
        valid_paths = []
        
        for i, img_path in enumerate(image_paths, 1):
            try:
                print(f"Processing image {i}/{total_images}: {os.path.basename(img_path)}")
                image = Image.open(img_path)
                if image.mode != 'RGB':
                    image = image.convert('RGB')
                    
                
                inputs = processor(images=image, return_tensors="pt")
                image_features = model.get_image_features(**inputs)
                
                
                embedding = image_features.detach().numpy()[0]
                embedding = embedding / np.linalg.norm(embedding)
                
                embeddings.append(embedding)
                valid_paths.append(img_path)
                print(f"Successfully processed {os.path.basename(img_path)}")
                
            except Exception as e:
                print(f"Error processing {img_path}: {str(e)}")
                continue
        
        if not embeddings:
            print("No valid images were processed")
            return
            
        
        all_embeddings = existing_embeddings + embeddings
        all_paths = existing_paths + valid_paths
        
        
        all_embeddings = np.array(all_embeddings)
        
        
        os.makedirs(output_dir, exist_ok=True)
        
        data = {
            'embeddings': all_embeddings,
            'image_paths': all_paths
        }
        
        with open(output_file, 'wb') as f:
            pickle.dump(data, f)
        
        print(f"Total images in index: {len(all_paths)}")
        print(f"New images added: {len(valid_paths)}")
        print(f"Embeddings shape: {all_embeddings.shape}")
        print(f"Saved to {output_file}")
        print("Indexing completed successfully!")
        
    except Exception as e:
        print(f"Failed to process images: {str(e)}")
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python generate_embeddings.py <image_directory>")
        sys.exit(1)
        
    image_dir = sys.argv[1]
    output_dir = "/Users/ausaf/Library/Application Support/searchy"
    
    if not os.path.exists(image_dir):
        print(f"Error: Directory '{image_dir}' does not exist")
        sys.exit(1)
        
    process_images(image_dir, output_dir)

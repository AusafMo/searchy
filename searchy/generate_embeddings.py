import torch
from PIL import Image
from torchvision.transforms import Compose, Resize, CenterCrop, ToTensor, Normalize
import os
import pickle
import numpy as np
from tqdm import tqdm
from transformers import CLIPProcessor, CLIPModel
import sys
import json

def process_images(image_dir, output_dir):
    try:
        # Initialize CLIP model and processor
        model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
        
        # Get all image files
        image_paths = []
        for root, dirs, files in os.walk(image_dir):
            for file in files:
                if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                    image_paths.append(os.path.join(root, file))
        
        if not image_paths:
            print(f"No images found in {image_dir}")
            return
            
        print(f"Found {len(image_paths)} images. Processing...")
        
        # Process images and get embeddings
        embeddings = []
        valid_paths = []
        
        for img_path in tqdm(image_paths):
            try:
                image = Image.open(img_path)
                if image.mode != 'RGB':
                    image = image.convert('RGB')
                    
                # Process image through CLIP
                inputs = processor(images=image, return_tensors="pt", padding=True)
                image_features = model.get_image_features(**inputs)
                
                # Convert to numpy and normalize
                embedding = image_features.detach().numpy()[0]
                embedding = embedding / np.linalg.norm(embedding)
                
                embeddings.append(embedding)
                valid_paths.append(img_path)
                
            except Exception as e:
                print(f"Error processing {img_path}: {str(e)}")
                continue
        
        if not embeddings:
            print("No valid images were processed")
            return
            
        # Convert to numpy array
        embeddings = np.array(embeddings)
        
        # Save embeddings and paths
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, 'image_index.bin')
        
        data = {
            'embeddings': embeddings,
            'image_paths': valid_paths
        }
        
        with open(output_file, 'wb') as f:
            pickle.dump(data, f)
        
        print(f"Processed {len(valid_paths)} images successfully")
        print(f"Embeddings shape: {embeddings.shape}")
        print(f"Saved to {output_file}")
        
    except Exception as e:
        print(f"Failed to process images: {str(e)}")

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

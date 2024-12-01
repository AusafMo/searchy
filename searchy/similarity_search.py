import torch
from PIL import Image
import os
import pickle
import numpy as np
from transformers import CLIPProcessor, CLIPModel
import sys
import json
import time

class CLIPSearcher:
    def __init__(self):
        # Use stderr for debug messages
        print("Loading CLIP model...", file=sys.stderr)
        start_time = time.time()
        self.model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        self.processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
        print(f"Model loaded in {time.time() - start_time:.2f} seconds", file=sys.stderr)

    def search(self, query, data_dir, top_k=5):
        try:
            # Load embeddings
            start_time = time.time()
            filename = os.path.join(data_dir, 'image_index.bin')
            if not os.path.exists(filename):
                return print(json.dumps({"error": "No image index found"}))

            load_start = time.time()
            with open(filename, 'rb') as f:
                data = pickle.load(f)
            print(f"Loaded index in {time.time() - load_start:.2f} seconds", file=sys.stderr)
                
            if not isinstance(data, dict) or 'embeddings' not in data or 'image_paths' not in data:
                return print(json.dumps({"error": "Invalid data format"}))
                
            embeddings = data['embeddings']
            image_paths = data['image_paths']
            
            if len(embeddings) == 0:
                return print(json.dumps({"error": "No images indexed"}))
                
            # Generate query embedding
            embedding_start = time.time()
            query_embedding = self.generate_text_embedding(query)
            print(f"Generated query embedding in {time.time() - embedding_start:.2f} seconds", file=sys.stderr)
            
            # Calculate similarities
            similarity_start = time.time()
            similarities = embeddings @ query_embedding
            sorted_indices = np.argsort(similarities)[::-1]
            print(f"Calculated similarities for {len(embeddings)} images in {time.time() - similarity_start:.2f} seconds", file=sys.stderr)
            
            results = []
            for idx in sorted_indices[:top_k]:
                results.append({
                    "path": image_paths[idx],
                    "similarity": float(similarities[idx])
                })
            
            total_time = time.time() - start_time
            final_output = {
                "results": results,
                "stats": {
                    "total_time": f"{total_time:.2f}s",
                    "images_searched": len(embeddings),
                    "images_per_second": f"{len(embeddings)/total_time:.2f}"
                }
            }
            
            # Only print the final JSON to stdout
            print(json.dumps(final_output))
            return results
                
        except Exception as e:
            return print(json.dumps({"error": str(e)}))

    def generate_text_embedding(self, text):  # Add this method
        inputs = self.processor(text=text, return_tensors="pt", padding=True)
        text_features = self.model.get_text_features(**inputs)
        embedding = text_features.detach().numpy()[0]
        return embedding / np.linalg.norm(embedding)

# Global instance
searcher = CLIPSearcher()

def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Missing arguments"}))
        return
        
    query = sys.argv[1]
    top_k = int(sys.argv[2])
    data_dir = sys.argv[3]
    
    searcher.search(query, data_dir, top_k)

if __name__ == "__main__":
    main()

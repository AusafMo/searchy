import torch
from PIL import Image
import os
import pickle
import numpy as np
from transformers import CLIPProcessor, CLIPModel
import sys
import json
import time

# Global model and processor instances
_model = None
_processor = None

def get_model_and_processor():
    global _model, _processor
    if _model is None or _processor is None:
        print("Loading CLIP model...", file=sys.stderr)
        _model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        _processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
    return _model, _processor



class CLIPSearcher:
    def __init__(self):
        self.model, self.processor = get_model_and_processor()  # Initialize model and processor once


    def generate_text_embedding(self, text):
        inputs = self.processor(text=text, return_tensors="pt", padding=True)
        text_features = self.model.get_text_features(**inputs)
        embedding = text_features.detach().numpy()[0]
        return embedding / np.linalg.norm(embedding)

    def search(self, query, data_dir, top_k=5):
        try:
            start_time = time.time()
            
            filename = os.path.join(data_dir, 'image_index.bin')
            if not os.path.exists(filename):
                return print(json.dumps({"error": "No image index found"}))

            with open(filename, 'rb') as f:
                data = pickle.load(f)
                
            if not isinstance(data, dict) or 'embeddings' not in data or 'image_paths' not in data:
                return print(json.dumps({"error": "Invalid data format"}))
                
            embeddings = data['embeddings']
            image_paths = data['image_paths']
            
            if len(embeddings) == 0:
                return print(json.dumps({"error": "No images indexed"}))
            
            print(f"Loaded {len(embeddings)} embeddings", file=sys.stderr)
            query_embedding = self.generate_text_embedding(query)
            
            similarities = embeddings @ query_embedding
            sorted_indices = np.argsort(similarities)[::-1]
            
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
            
            print(json.dumps(final_output))
            return final_output
            
        except Exception as e:
            print(json.dumps({"error": str(e)}))
            return None

# Keep a global instance
_searcher = CLIPSearcher()

def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Missing arguments"}))
        return
        
    query = sys.argv[1]
    top_k = int(sys.argv[2])
    data_dir = sys.argv[3]
    
    _searcher.search(query, data_dir, top_k)

if __name__ == "__main__":
    main()

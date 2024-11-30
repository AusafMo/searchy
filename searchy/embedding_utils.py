import pickle
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import os
import sys
import json

def save_embeddings(embeddings, image_paths, data_dir):
    try:
        filename = os.path.join(data_dir, 'image_index.bin')
        data = {'embeddings': embeddings, 'image_paths': image_paths}
        with open(filename, 'wb') as f:
            pickle.dump(data, f)
        return True
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        return False

def load_embeddings(data_dir):
    try:
        filename = os.path.join(data_dir, 'image_index.bin')
        
        if not os.path.exists(filename):
            # Create empty embeddings file
            empty_embeddings = np.empty((0, 512))
            empty_image_paths = []
            if not save_embeddings(empty_embeddings, empty_image_paths, data_dir):
                print(json.dumps({"error": "Failed to create initial embeddings file"}))
                return None, None
        
        with open(filename, 'rb') as f:
            data = pickle.load(f)
            
        if not isinstance(data, dict) or 'embeddings' not in data or 'image_paths' not in data:
            print(json.dumps({"error": "Invalid data format in embeddings file"}))
            return None, None
            
        embeddings = np.array(data['embeddings'])
        image_paths = data['image_paths']
        
        if embeddings.size == 0 or len(image_paths) == 0:
            print(json.dumps({"error": "No embeddings or image paths found"}))
            return None, None
            
        return embeddings, image_paths
        
    except Exception as e:
        print(json.dumps({"error": f"Failed to load embeddings: {str(e)}"}))
        return None, None

def semantic_search(query_embedding, embeddings, image_paths, top_k=5):
    if query_embedding is None or embeddings is None or image_paths is None:
        print(json.dumps({"error": "Missing data for search"}))
        return None
        
    try:
        similarities = cosine_similarity([query_embedding], embeddings)[0]
        sorted_indices = np.argsort(similarities)[::-1]
        
        results = []
        for idx in sorted_indices[:top_k]:
            results.append({
                "path": image_paths[idx],
                "similarity": float(similarities[idx])
            })
            
        print(json.dumps(results))
        return results
    except Exception as e:
        print(json.dumps({"error": f"Search failed: {str(e)}"}))
        return None

def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Missing required arguments"}))
        return

    data_dir = sys.argv[3].strip()
    if not data_dir:
        print(json.dumps({"error": "Invalid data directory"}))
        return
        
    try:
        os.makedirs(data_dir, exist_ok=True)
    except Exception as e:
        print(json.dumps({"error": f"Failed to create directory: {str(e)}"}))
        return
        
    embeddings, image_paths = load_embeddings(data_dir)
    if embeddings is None or image_paths is None:
        return

if __name__ == "__main__":
    main()

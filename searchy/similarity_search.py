import pickle
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity
import os
import sys
import json
from transformers import CLIPProcessor, CLIPModel

def generate_query_embedding(query_text, model, processor):
    try:
        # Process text through CLIP
        inputs = processor(text=query_text, return_tensors="pt", padding=True)
        text_features = model.get_text_features(**inputs)
        
        # Convert to numpy and normalize
        embedding = text_features.detach().numpy()[0]
        embedding = embedding / np.linalg.norm(embedding)
        
        return embedding
    except Exception as e:
        print(json.dumps({"error": f"Failed to generate query embedding: {str(e)}"}))
        return None

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
        index_path = os.path.join(data_dir, 'image_index.bin')
        
        if not os.path.exists(index_path):
            print(json.dumps({"error": f"No image index found at {index_path}"}))
            return None, None
            
        with open(index_path, 'rb') as f:
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

    query = sys.argv[1]
    top_k = int(sys.argv[2])
    data_dir = sys.argv[3]

    try:
        # Initialize CLIP
        model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
        
        # Generate query embedding
        query_embedding = generate_query_embedding(query, model, processor)
        if query_embedding is None:
            return
            
        # Load image embeddings
        embeddings, image_paths = load_embeddings(data_dir)
        if embeddings is None or image_paths is None:
            return
            
        # Perform search
        semantic_search(query_embedding, embeddings, image_paths, top_k)
        
    except Exception as e:
        print(json.dumps({"error": f"Search process failed: {str(e)}"}))

if __name__ == "__main__":
    main()

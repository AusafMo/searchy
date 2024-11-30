#
//  similarity_search.py
//  searchy
//
//  Created by Mohammad Ausaf on 28/11/24.
//

import sys
from embedding_utils import load_embeddings, semantic_search
from clip_model import generate_text_embedding
import json

def perform_similarity_search(query_text, num_results=5):
    try:
        # Load pre-computed embeddings and image paths
        embeddings, image_paths = load_embeddings('image_index.bin')
        if embeddings is None or image_paths is None:
            raise ValueError("Failed to load embeddings")
            
        # Generate embedding for the search query
        query_embedding = generate_text_embedding(query_text)
        if query_embedding is None:
            raise ValueError("Failed to generate query embedding")
            
        # Perform semantic search
        similarities, result_images = semantic_search(query_embedding, embeddings, image_paths)
        
        # Format results
        results = []
        for sim, img_path in zip(similarities[:num_results], result_images[:num_results]):
            results.append({
                "path": img_path,
                "similarity": float(sim)  # Convert numpy float to Python float
            })
            
        # Return results as JSON
        print(json.dumps(results))
        
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No query provided"}))
        sys.exit(1)
        
    query = sys.argv[1]
    num_results = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    perform_similarity_search(query, num_results)

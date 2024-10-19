import pickle
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# Function to save embeddings with error handling
def save_embeddings(embeddings, image_paths, filename='image_index.bin'):
    try:
        data = {'embeddings': embeddings, 'image_paths': image_paths}
        with open(filename, 'wb') as f:
            pickle.dump(data, f)
        print(f"Embeddings saved to {filename}")
    except Exception as e:
        print(f"Error saving embeddings: {e}")

# Function to load embeddings with error handling
def load_embeddings(filename='image_index.bin'):
    try:
        with open(filename, 'rb') as f:
            data = pickle.load(f)

        # Print the type and structure of `data` to understand the issue
        print(f"Loaded data type: {type(data)}")
        print(f"Loaded data: {data}")

        # Check if 'embeddings' and 'image_paths' are present in data
        if not isinstance(data, dict):
            raise ValueError("Data is not a dictionary.")

        if 'embeddings' not in data or 'image_paths' not in data:
            raise ValueError("Invalid data format in file: 'embeddings' or 'image_paths' key missing.")

        embeddings = np.array(data['embeddings'])
        image_paths = data['image_paths']

        # Check if embeddings are non-empty
        if embeddings.size == 0 or len(image_paths) == 0:
            raise ValueError("No embeddings or image paths found.")

        return embeddings, image_paths

    except FileNotFoundError:
        print(f"File '{filename}' not found. Please build the index first.")
        return None, None
    except ValueError as ve:
        print(f"Data format error: {ve}")
        return None, None
    except Exception as e:
        print(f"Error loading embeddings: {e}")
        return None, None

# Perform semantic search with error handling
def semantic_search(query_embedding, embeddings, image_paths, top_k=5):
    if query_embedding is None or embeddings is None or image_paths is None:
        print("Cannot perform search: missing embeddings or query.")
        return

    try:
        similarities = cosine_similarity([query_embedding], embeddings)[0]
        sorted_indices = np.argsort(similarities)[::-1]

        # Return formatted results for display
        result_text = f"Top {top_k} most similar images:\n"
        result_list = []
        for idx in sorted_indices[:top_k]:
            result_text += f"Image: {image_paths[idx]}, Similarity: {similarities[idx]:.4f}\n"
            result_list.append(image_paths[idx])
        
        return result_text, result_list
    except Exception as e:
        print(f"Error during semantic search: {e}")
        return "Error during search."

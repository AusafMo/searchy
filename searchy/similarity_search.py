import torch
from PIL import Image
import os
import pickle
import numpy as np
from transformers import CLIPProcessor, CLIPModel
import sys
import json
import time


_model = None
_processor = None
_device = None

def get_device():
    """Get the best available device (MPS for Apple Silicon, CUDA, or CPU)"""
    global _device
    if _device is None:
        if torch.backends.mps.is_available():
            _device = torch.device("mps")
            print(f"🚀 Using Apple Metal (MPS) acceleration", file=sys.stderr)
        elif torch.cuda.is_available():
            _device = torch.device("cuda")
            print(f"🚀 Using CUDA GPU acceleration", file=sys.stderr)
        else:
            _device = torch.device("cpu")
            print(f"💻 Using CPU", file=sys.stderr)
    return _device

def get_model_and_processor():
    global _model, _processor
    if _model is None or _processor is None:
        print("Loading CLIP model...", file=sys.stderr)
        model_name = "openai/clip-vit-base-patch32"

        try:
            print(f"Loading {model_name}...", file=sys.stderr)
            _model = CLIPModel.from_pretrained(model_name, token=False)
            _processor = CLIPProcessor.from_pretrained(model_name, token=False)

            # Move model to GPU if available
            device = get_device()
            _model = _model.to(device)

            print(f"✅ Successfully loaded {model_name} on {device}", file=sys.stderr)
        except Exception as e:
            print(f"Error loading CLIP model: {e}", file=sys.stderr)
            raise Exception(f"Could not load CLIP model: {e}")

    return _model, _processor



def text_match_score(query: str, ocr_text: str) -> float:
    """Calculate text match score between query and OCR text."""
    if not ocr_text or not query:
        return 0.0

    query_lower = query.lower()
    ocr_lower = ocr_text.lower()

    # Exact match gets highest score
    if query_lower in ocr_lower:
        return 1.0

    # Word-level matching
    query_words = set(query_lower.split())
    ocr_words = set(ocr_lower.split())

    if not query_words:
        return 0.0

    # Calculate how many query words are found in OCR text
    matches = len(query_words & ocr_words)
    return matches / len(query_words)


class CLIPSearcher:
    def __init__(self):
        self.model, self.processor = get_model_and_processor()
        self.device = get_device()

    def generate_text_embedding(self, text):
        inputs = self.processor(text=text, return_tensors="pt", padding=True)
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        with torch.no_grad():
            text_features = self.model.get_text_features(**inputs)
        embedding = text_features.cpu().numpy()[0]
        return embedding / np.linalg.norm(embedding)

    def generate_image_embedding(self, image_path):
        """Generate CLIP embedding for an image file."""
        from PIL import Image
        try:
            image = Image.open(image_path)
            if image.mode != 'RGB':
                image = image.convert('RGB')

            inputs = self.processor(images=image, return_tensors="pt")
            inputs = {k: v.to(self.device) for k, v in inputs.items()}

            with torch.no_grad():
                image_features = self.model.get_image_features(**inputs)

            embedding = image_features.cpu().numpy()[0]
            return embedding / np.linalg.norm(embedding)
        except Exception as e:
            print(f"Error generating embedding for {image_path}: {e}", file=sys.stderr)
            return None

    def find_similar(self, image_path, data_dir, top_k=20):
        """Find images similar to the given image."""
        try:
            start_time = time.time()

            # Generate embedding for query image
            query_embedding = self.generate_image_embedding(image_path)
            if query_embedding is None:
                return {"error": f"Could not process image: {image_path}"}

            # Load index
            filename = os.path.join(data_dir, 'image_index.bin')
            if not os.path.exists(filename):
                return {"error": "No images indexed yet. Please index a folder first."}

            with open(filename, 'rb') as f:
                data = pickle.load(f)

            embeddings = data['embeddings']
            image_paths = data['image_paths']

            if len(embeddings) == 0:
                return {"error": "No images indexed yet."}

            # Compute similarities
            similarities = embeddings @ query_embedding
            sorted_indices = np.argsort(similarities)[::-1]

            # Build results, excluding the query image itself
            results = []
            for idx in sorted_indices:
                if image_paths[idx] == image_path:
                    continue  # Skip the query image
                if len(results) >= top_k:
                    break
                results.append({
                    "path": image_paths[idx],
                    "similarity": float(similarities[idx])
                })

            total_time = time.time() - start_time
            return {
                "results": results,
                "query_image": image_path,
                "stats": {
                    "total_time": f"{total_time:.2f}s",
                    "images_searched": len(embeddings),
                    "images_per_second": f"{len(embeddings)/total_time:.2f}"
                }
            }

        except Exception as e:
            print(f"Error in find_similar: {e}", file=sys.stderr)
            return {"error": str(e)}

    def search(self, query, data_dir, top_k=5, ocr_weight=0.3):
        try:
            start_time = time.time()

            filename = os.path.join(data_dir, 'image_index.bin')
            if not os.path.exists(filename):
                error_response = {"error": "No images indexed yet. Please index a folder first."}
                print(json.dumps(error_response))
                return error_response

            with open(filename, 'rb') as f:
                data = pickle.load(f)

            if not isinstance(data, dict) or 'embeddings' not in data or 'image_paths' not in data:
                error_response = {"error": "Invalid index format. Please re-index."}
                print(json.dumps(error_response))
                return error_response

            embeddings = data['embeddings']
            image_paths = data['image_paths']
            ocr_texts = data.get('ocr_texts', [''] * len(image_paths))

            if len(embeddings) == 0:
                error_response = {"error": "No images indexed yet. Please index a folder first."}
                print(json.dumps(error_response))
                return error_response

            print(f"Loaded {len(embeddings)} embeddings", file=sys.stderr)
            query_embedding = self.generate_text_embedding(query)

            # Semantic similarity from CLIP
            semantic_scores = embeddings @ query_embedding

            # OCR text matching scores
            ocr_scores = np.array([text_match_score(query, ocr_text) for ocr_text in ocr_texts])

            # Combine scores: use semantic as base, OCR as boost (not reduction)
            # Only apply OCR boost where there's actually OCR text that matches
            combined_scores = semantic_scores.copy()
            for i, (ocr_score, ocr_text) in enumerate(zip(ocr_scores, ocr_texts)):
                if ocr_text and ocr_score > 0:
                    # Boost score when OCR matches, but don't reduce semantic scores
                    combined_scores[i] = semantic_scores[i] + ocr_score * ocr_weight
                    # Cap at 1.0
                    combined_scores[i] = min(combined_scores[i], 1.0)

            # Extra boost for exact text matches
            for i, ocr_text in enumerate(ocr_texts):
                if ocr_text and query.lower() in ocr_text.lower():
                    combined_scores[i] = max(combined_scores[i], 0.95)

            sorted_indices = np.argsort(combined_scores)[::-1]

            results = []
            for idx in sorted_indices[:top_k]:
                result = {
                    "path": image_paths[idx],
                    "similarity": float(combined_scores[idx])
                }
                # Include OCR text if found
                if ocr_texts[idx]:
                    result["ocr_text"] = ocr_texts[idx][:200]  # Truncate for response
                results.append(result)

            total_time = time.time() - start_time
            ocr_count = sum(1 for t in ocr_texts if t.strip())
            final_output = {
                "results": results,
                "stats": {
                    "total_time": f"{total_time:.2f}s",
                    "images_searched": len(embeddings),
                    "images_per_second": f"{len(embeddings)/total_time:.2f}",
                    "images_with_ocr": ocr_count
                }
            }

            print(json.dumps(final_output))
            return final_output

        except Exception as e:
            print(json.dumps({"error": str(e)}))
            return None


def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Missing arguments"}))
        return

    query = sys.argv[1]
    top_k = int(sys.argv[2])
    data_dir = sys.argv[3]

    searcher = CLIPSearcher()
    searcher.search(query, data_dir, top_k)

if __name__ == "__main__":
    main()

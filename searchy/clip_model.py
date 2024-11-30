import torch
from transformers import CLIPProcessor, CLIPModel

try:
    model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
    processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
except Exception as e:
    print(f"Error loading CLIP model: {e}")
    raise SystemExit

def generate_image_embedding(image):
    try:
        inputs = processor(images=image, return_tensors="pt")
        with torch.no_grad():
            image_embedding = model.get_image_features(**inputs).cpu().numpy().flatten()
        print(f"Image Embedding Shape: {image_embedding.shape}")
        return image_embedding
    except Exception as e:
        print(f"Error generating image embedding: {e}")
        return None

def generate_text_embedding(query_text):
    try:
        inputs = processor(text=query_text, return_tensors="pt")
        with torch.no_grad():
            text_embedding = model.get_text_features(**inputs).cpu().numpy().flatten()
        print(f"Text Embedding Shape: {text_embedding.shape}")
        return text_embedding
    except Exception as e:
        print(f"Error generating text embedding: {e}")
        return None

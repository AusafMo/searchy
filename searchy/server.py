import os
import argparse
import logging
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from similarity_search import CLIPSearcher
import uvicorn


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


app = FastAPI()

# Lazy initialization of searcher
_searcher = None

def get_searcher():
    global _searcher
    if _searcher is None:
        _searcher = CLIPSearcher()
    return _searcher


class SearchRequest(BaseModel):
    query: str
    top_k: int
    data_dir: str

@app.post("/search")
def search(request: SearchRequest):
    """
    Perform a similarity search based on the query.
    """
    try:
        logger.info(f"Received search request: {request}")
        searcher = get_searcher()
        results = searcher.search(request.query, request.data_dir, request.top_k)
        return results
    except Exception as e:
        logger.error(f"Error during search: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/status")
def get_status():
    return {"status": "Server is running"}

@app.get("/recent")
def get_recent(top_k: int = 8, data_dir: str = "/Users/ausaf/Library/Application Support/searchy"):
    """
    Get recent indexed images sorted by modification date (newest first).
    """
    try:
        import pickle
        import os

        filename = os.path.join(data_dir, 'image_index.bin')
        if not os.path.exists(filename):
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        with open(filename, 'rb') as f:
            data = pickle.load(f)

        if not isinstance(data, dict) or 'image_paths' not in data:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        image_paths = data['image_paths']

        if len(image_paths) == 0:
            return {"results": [], "stats": {"total_time": "0.00s", "images_searched": 0, "images_per_second": "0"}}

        # Get creation/added times for all indexed images
        images_with_time = []
        for path in image_paths:
            if os.path.exists(path):
                try:
                    # Use birthtime (actual creation time on macOS) or fallback to ctime
                    stat_info = os.stat(path)
                    # On macOS, st_birthtime is the actual creation time
                    creation_time = getattr(stat_info, 'st_birthtime', stat_info.st_ctime)
                    images_with_time.append((path, creation_time))
                except:
                    continue

        # Sort by creation time (newest first)
        images_with_time.sort(key=lambda x: x[1], reverse=True)

        # Take top_k newest
        recent_images = images_with_time[:top_k]

        # Debug: Log directories of recent images
        import sys
        from collections import Counter
        dirs = [os.path.dirname(path) for path, _ in recent_images]
        dir_counts = Counter(dirs)
        print(f"📊 Recent images by directory:", file=sys.stderr)
        for dir_path, count in dir_counts.most_common():
            print(f"  {dir_path}: {count} images", file=sys.stderr)

        # Create results with dummy similarity scores
        results = [{"path": path, "similarity": 1.0} for path, _ in recent_images]

        return {
            "results": results,
            "stats": {
                "total_time": "0.00s",
                "images_searched": len(image_paths),
                "images_per_second": "0"
            }
        }
    except Exception as e:
        logger.error(f"Error fetching recent images: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on")
    args = parser.parse_args()

    
    port = args.port
    logger.info(f"Starting server on port {port}")

    
    uvicorn.run(app, host="0.0.0.0", port=port)

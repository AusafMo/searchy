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


searcher = CLIPSearcher()


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
        results = searcher.search(request.query, request.data_dir, request.top_k)
        return results
    except Exception as e:
        logger.error(f"Error during search: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/status")
def get_status():
    return {"status": "Server is running"}

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=7860, help="Port to run the server on")
    args = parser.parse_args()

    
    port = args.port
    logger.info(f"Starting server on port {port}")

    
    uvicorn.run(app, host="0.0.0.0", port=port)

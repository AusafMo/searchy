from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from similarity_search import CLIPSearcher
import os
import uvicorn
import logging

# Initialize the logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize the FastAPI app
app = FastAPI()

# Initialize the searcher globally for reuse
searcher = CLIPSearcher()

# Define the request model
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

if __name__ == "__main__":
    # Get the port from the environment or default to 7860
    port = int(os.getenv("PORT", 7860))
    logger.info(f"Starting server on port {port}")
    uvicorn.run(app, host="0.0.0.0", port=port)

from fastapi import FastAPI
from pydantic import BaseModel
from similarity_search import CLIPSearcher

app = FastAPI()

class SearchRequest(BaseModel):
    query: str
    top_k: int
    data_dir: str

@app.post("/search")
def search(request: SearchRequest):
    searcher = CLIPSearcher()
    print(SearchRequest)
    return searcher.search(request.query, request.data_dir, request.top_k)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)

from fastapi import FastAPI
from datetime import datetime
import os

app = FastAPI()

@app.get("/api/v1/status")
def status():
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "service": os.getenv("SERVICE_NAME", "backend")
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

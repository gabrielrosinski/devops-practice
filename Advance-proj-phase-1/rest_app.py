import os
from fastapi import FastAPI
from pydantic import BaseModel
from dotenv import load_dotenv
import uvicorn

load_dotenv()

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 5000))
RELOAD = os.getenv("RELOAD", "true").lower() == "true"

app = FastAPI()

class User(BaseModel):
    user_name: str

@app.post("/users")
async def create_user(user: User):
    return {"user_name": user.user_name}

@app.get("/users")
async def root():
    return {"message": "Hello World"}

@app.put("")
async def root():
    return {"message": "Hello World"}

@app.delete("")
async def root():
    return {"message": "Hello World"}

if __name__ == "__main__":
    uvicorn.run(
        "rest_app:app",  # file_name:fastapi_instance
        host=HOST,
        port=PORT,
        reload=RELOAD
    )
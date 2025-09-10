import os
from fastapi import FastAPI, Depends
from pydantic import BaseModel
from dotenv import load_dotenv
import uvicorn
from db_connector import Database
from typing import Optional
from datetime import datetime

load_dotenv()

db = Database()

def get_db():
    connection = db.get_connection()
    try:
        yield connection
    finally:
        connection.close()

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 5000))
RELOAD = os.getenv("RELOAD", "true").lower() == "true"

app = FastAPI()

class User(BaseModel):
    user_name: str
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

@app.post("/users")
async def create_user(user: User, conn = Depends(get_db)):
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO users (user_name, created_at) VALUES (%s, NOW())", (user.user_name,))
        conn.commit()
        user_id = cursor.lastrowid
        return {"message": "User created successfully", "user_id": user_id, "user_name": user.user_name}
    finally:
        cursor.close()

@app.get("/users")
async def get_all_users(conn = Depends(get_db)):
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM users")
        users = cursor.fetchall()
        return {"users": users}
    finally:
        cursor.close()

@app.get("/users/{user_id}")
async def get_user(user_id: int, conn = Depends(get_db)):
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if user is None:
            return {"error": "User not found"}
        return {"user": user}
    finally:
        cursor.close()

@app.put("/users/{user_id}")
async def update_user_name(user_id: int, conn = Depends(get_db)):
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE users SET user_name = %s, updated_at = NOW() WHERE id = %s", (user.user_name, user_id))
        conn.commit()
        if cursor.rowcount == 0:
            return {"error": "User not found"}
        return {"message": "User updated successfully", "user_id": user_id, "user_name": user.user_name}
    finally:
        cursor.close()

@app.delete("/users/{user_id}")
async def delete_user(user_id: int, conn = Depends(get_db)):
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id))
        conn.commit()
        if cursor.rowcount == 0:
            return {"error": "User not found"}
        return {"message": f"User with id {user_id} was deleted successfully"}
    finally:
        cursor.close()

if __name__ == "__main__":
    uvicorn.run(
        "rest_app:app",  # file_name:fastapi_instance
        host=HOST,
        port=PORT,
        reload=RELOAD
    )
from fastapi import APIRouter, HTTPException, Body
from database import users_collection as db
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr
from bson import ObjectId


router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

class UserIn(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: str
    name: str
    email: EmailStr

@router.get("/")
async def get_users():
    users = await db.find().to_list(1000)
    # Hide password hashes in output
    for user in users:
        user["id"] = str(user["_id"])
        user.pop("_id", None)
        user.pop("password", None)
    return users

@router.post("/")
async def create_user(user: UserIn):
    # Check for existing email
    existing_user = await db.find_one({"email": user.email})
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already exists")
    hashed_password = pwd_context.hash(user.password)
    user_dict = user.dict()
    user_dict["password"] = hashed_password
    result = await db.insert_one(user_dict)
    return {"id": str(result.inserted_id), "message": "User created successfully"}

@router.post("/login")
async def login_user(data: dict = Body(...)):
    email = data.get("email")
    password = data.get("password")
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password are required")
    user = await db.find_one({"email": email})
    if not user or not pwd_context.verify(password, user["password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return {
        "id": str(user["_id"]),
        "name": user.get("name"),
        "email": user.get("email")
    }

@router.get("/{user_id}")
async def get_user(user_id: str):
    user = await db.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user["id"] = str(user["_id"])
    user.pop("_id", None)
    user.pop("password", None)
    return user

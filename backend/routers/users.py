import asyncio
from fastapi import APIRouter, HTTPException, Body, Depends
from database import users_collection as db, recipes_collection, follows_collection
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr
from bson import ObjectId
from auth import create_access_token, get_current_user_id

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class UserIn(BaseModel):
    name: str
    email: EmailStr
    password: str


@router.post("/")
async def create_user(user: UserIn):
    existing = await db.find_one({"email": user.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already exists")
    user_dict = user.dict()
    user_dict["password"] = pwd_context.hash(user_dict["password"])
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
    user_id = str(user["_id"])
    token = create_access_token(user_id)
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {"id": user_id, "name": user.get("name"), "email": user.get("email")},
    }


@router.get("/me")
async def get_me(user_id: str = Depends(get_current_user_id)):
    user = await db.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {"id": str(user["_id"]), "name": user.get("name"), "email": user.get("email")}


@router.get("/search")
async def search_users(q: str = ""):
    if not q.strip():
        return []
    cursor = db.find({"name": {"$regex": q.strip(), "$options": "i"}}).limit(20)
    results = []
    async for u in cursor:
        results.append({"id": str(u["_id"]), "name": u.get("name", "")})
    return results


@router.get("/{user_id}/followers")
async def get_followers(user_id: str):
    cursor = follows_collection.find({"following_id": user_id})
    results = []
    async for f in cursor:
        follower_id = f.get("follower_id")
        if not follower_id:
            continue
        try:
            user = await db.find_one({"_id": ObjectId(follower_id)})
        except Exception:
            continue
        if user:
            results.append({"id": str(user["_id"]), "name": user.get("name", "")})
    return results


@router.get("/{user_id}/following")
async def get_following(user_id: str):
    cursor = follows_collection.find({"follower_id": user_id})
    results = []
    async for f in cursor:
        following_id = f.get("following_id")
        if not following_id:
            continue
        try:
            user = await db.find_one({"_id": ObjectId(following_id)})
        except Exception:
            continue
        if user:
            results.append({"id": str(user["_id"]), "name": user.get("name", "")})
    return results


@router.get("/{user_id}/recipes")
async def get_user_public_recipes(user_id: str):
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user_id")
    cursor = recipes_collection.find({"user_id": oid, "is_public": True})
    results = []
    async for r in cursor:
        r["_id"] = str(r["_id"])
        r["user_id"] = str(r["user_id"])
        results.append(r)
    return results


@router.get("/{user_id}")
async def get_user(user_id: str):
    user = await db.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    uid = str(user["_id"])
    follower_count, following_count, recipe_count = await asyncio.gather(
        follows_collection.count_documents({"following_id": uid}),
        follows_collection.count_documents({"follower_id":  uid}),
        recipes_collection.count_documents({"user_id": user["_id"], "is_public": True}),
    )
    return {
        "id": uid,
        "name": user.get("name"),
        "email": user.get("email"),
        "follower_count":      follower_count,
        "following_count":     following_count,
        "public_recipe_count": recipe_count,
    }

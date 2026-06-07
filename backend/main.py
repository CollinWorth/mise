from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from contextlib import asynccontextmanager
import os
from bson import ObjectId
from database import (
    client, db, images_collection,
    recipes_collection, follows_collection, comments_collection, ratings_collection,
)
from routers import users, recipes, mealPlans, groceryList, follows, comments, ratings


@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        await client.admin.command('ping')
        print("MongoDB connection successful")
        # One rating per (recipe, user); plus indexes on hot query fields.
        await ratings_collection.create_index([("recipe_id", 1), ("user_id", 1)], unique=True)
        await recipes_collection.create_index([("user_id", 1)])
        await recipes_collection.create_index([("is_public", 1)])
        await recipes_collection.create_index([("original_recipe_id", 1)])
        await follows_collection.create_index([("follower_id", 1)])
        await follows_collection.create_index([("following_id", 1)])
        await comments_collection.create_index([("recipe_id", 1)])
    except Exception as e:
        print(f"MongoDB startup error: {e}")
    yield
    client.close()


app = FastAPI(lifespan=lifespan)

# Allowed CORS origins, comma-separated, via env (defaults to local dev hosts).
_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:3001")
ALLOWED_ORIGINS = [o.strip() for o in _origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

app.include_router(recipes.router, prefix="/recipes", tags=["recipes"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(mealPlans.router, prefix="/mealPlans", tags=["mealPlans"])
app.include_router(groceryList.router, prefix="/groceryList", tags=["groceryList"])
app.include_router(follows.router,     prefix="/follows",     tags=["follows"])
app.include_router(comments.router,    prefix="/comments",    tags=["comments"])
app.include_router(ratings.router,     prefix="/ratings",     tags=["ratings"])

@app.get("/images/{image_id}")
async def serve_image(image_id: str):
    try:
        doc = await images_collection.find_one({"_id": ObjectId(image_id)})
    except Exception:
        raise HTTPException(status_code=404)
    if not doc:
        raise HTTPException(status_code=404)
    return Response(content=doc["data"], media_type=doc.get("content_type", "image/jpeg"))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
import os
from bson import ObjectId
from database import client, db, images_collection
from routers import users, recipes, mealPlans, groceryList, follows, comments, ratings

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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

@app.on_event("startup")
async def startup_db_client():
    try:
        await client.admin.command('ping')
        print("MongoDB connection successful")
        from database import ratings_collection
        await ratings_collection.create_index(
            [("recipe_id", 1), ("user_id", 1)], unique=True
        )
    except Exception as e:
        print(f"MongoDB startup error: {e}")

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()

from fastapi import APIRouter, HTTPException, Depends
from bson import ObjectId
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from database import ratings_collection, recipes_collection, users_collection
from auth import get_current_user_id, get_optional_user_id

router = APIRouter()


class RatingIn(BaseModel):
    rating: int = Field(..., ge=1, le=3)


async def _resolve_recipe_id(recipe_id: str) -> str:
    """Redirect rating to the original if this is a remix."""
    doc = await recipes_collection.find_one(
        {"_id": ObjectId(recipe_id)},
        {"is_modified": 1, "original_recipe_id": 1}
    )
    if doc and doc.get("is_modified") and doc.get("original_recipe_id"):
        return str(doc["original_recipe_id"])
    return recipe_id


async def _recalculate_recipe_rating(recipe_id: str):
    pipeline = [
        {"$match": {"recipe_id": recipe_id}},
        {"$group": {"_id": None, "avg": {"$avg": "$rating"}, "count": {"$sum": 1}}}
    ]
    result = await ratings_collection.aggregate(pipeline).to_list(1)
    if result:
        avg = round(result[0]["avg"], 2)
        count = result[0]["count"]
    else:
        avg = 0.0
        count = 0
    await recipes_collection.update_one(
        {"_id": ObjectId(recipe_id)},
        {"$set": {"avg_rating": avg, "rating_count": count}}
    )
    return avg, count


@router.post("/{recipe_id}")
async def rate_recipe(recipe_id: str, body: RatingIn, user_id: str = Depends(get_current_user_id)):
    recipe_id = await _resolve_recipe_id(recipe_id)
    recipe = await recipes_collection.find_one({"_id": ObjectId(recipe_id)})
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")
    now = datetime.utcnow()
    await ratings_collection.update_one(
        {"recipe_id": recipe_id, "user_id": user_id},
        {
            "$set": {"rating": body.rating, "updated_at": now},
            "$setOnInsert": {"created_at": now},
        },
        upsert=True,
    )
    avg, count = await _recalculate_recipe_rating(recipe_id)
    return {"avg_rating": avg, "rating_count": count, "user_rating": body.rating}


@router.delete("/{recipe_id}")
async def delete_rating(recipe_id: str, user_id: str = Depends(get_current_user_id)):
    recipe_id = await _resolve_recipe_id(recipe_id)
    result = await ratings_collection.delete_one({"recipe_id": recipe_id, "user_id": user_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Rating not found")
    avg, count = await _recalculate_recipe_rating(recipe_id)
    return {"avg_rating": avg, "rating_count": count, "user_rating": None}


@router.get("/{recipe_id}")
async def get_ratings(recipe_id: str, current_user_id: Optional[str] = Depends(get_optional_user_id)):
    recipe_id = await _resolve_recipe_id(recipe_id)
    recipe = await recipes_collection.find_one({"_id": ObjectId(recipe_id)})
    if not recipe:
        raise HTTPException(status_code=404, detail="Recipe not found")

    avg_rating = recipe.get("avg_rating", 0.0)
    rating_count = recipe.get("rating_count", 0)

    rating_docs = await ratings_collection.find({"recipe_id": recipe_id}).to_list(None)

    user_obj_ids = []
    for r in rating_docs:
        try:
            user_obj_ids.append(ObjectId(r["user_id"]))
        except Exception:
            pass

    name_map = {}
    if user_obj_ids:
        user_docs = await users_collection.find({"_id": {"$in": user_obj_ids}}).to_list(None)
        name_map = {str(u["_id"]): u.get("name", "Chef") for u in user_docs}

    user_rating = None
    raters = []
    for r in rating_docs:
        uid = r["user_id"]
        if current_user_id and uid == current_user_id:
            user_rating = r["rating"]
        raters.append({
            "user_id": uid,
            "user_name": name_map.get(uid, "Chef"),
            "rating": r["rating"],
        })

    return {
        "avg_rating": avg_rating,
        "rating_count": rating_count,
        "user_rating": user_rating,
        "raters": raters,
    }

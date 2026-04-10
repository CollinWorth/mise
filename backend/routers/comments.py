from fastapi import APIRouter, HTTPException, Depends
from bson import ObjectId
from database import comments_collection, users_collection
from auth import get_current_user_id
from pydantic import BaseModel
from datetime import datetime

router = APIRouter()


class CommentIn(BaseModel):
    text: str
    parent_id: str | None = None


@router.get("/{recipe_id}")
async def get_comments(recipe_id: str):
    cursor = comments_collection.find({"recipe_id": recipe_id}).sort("created_at", 1)
    comments = []
    async for c in cursor:
        c["_id"] = str(c["_id"])
        comments.append(c)
    return comments


@router.post("/{recipe_id}")
async def add_comment(recipe_id: str, body: CommentIn, user_id: str = Depends(get_current_user_id)):
    if not body.text.strip():
        raise HTTPException(status_code=400, detail="Comment cannot be empty")
    user = await users_collection.find_one({"_id": ObjectId(user_id)})
    user_name = user.get("name", "Chef") if user else "Chef"
    doc = {
        "recipe_id": recipe_id,
        "user_id":   user_id,
        "user_name": user_name,
        "text":      body.text.strip(),
        "parent_id": body.parent_id or None,
        "created_at": datetime.utcnow(),
    }
    result = await comments_collection.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.delete("/{comment_id}")
async def delete_comment(comment_id: str, user_id: str = Depends(get_current_user_id)):
    comment = await comments_collection.find_one({"_id": ObjectId(comment_id)})
    if not comment:
        raise HTTPException(status_code=404, detail="Comment not found")
    if comment["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="Cannot delete others' comments")
    await comments_collection.delete_one({"_id": ObjectId(comment_id)})
    return {"message": "Deleted"}

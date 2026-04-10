from fastapi import APIRouter, HTTPException, Depends
from bson import ObjectId
from database import follows_collection
from auth import get_current_user_id
from datetime import datetime

router = APIRouter()


@router.post("/{target_id}")
async def follow_user(target_id: str, user_id: str = Depends(get_current_user_id)):
    if user_id == target_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    existing = await follows_collection.find_one({"follower_id": user_id, "following_id": target_id})
    if existing:
        return {"message": "Already following"}
    await follows_collection.insert_one({
        "follower_id": user_id,
        "following_id": target_id,
        "created_at": datetime.utcnow(),
    })
    return {"message": "Following"}


@router.delete("/{target_id}")
async def unfollow_user(target_id: str, user_id: str = Depends(get_current_user_id)):
    result = await follows_collection.delete_one({"follower_id": user_id, "following_id": target_id})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Not following")
    return {"message": "Unfollowed"}


@router.get("/{target_id}/status")
async def follow_status(target_id: str, user_id: str = Depends(get_current_user_id)):
    existing = await follows_collection.find_one({"follower_id": user_id, "following_id": target_id})
    return {"is_following": existing is not None}

from fastapi import APIRouter, HTTPException
from model import GroceryList, GroceryItem
from pydantic import BaseModel
from bson import ObjectId
from database import grocery_collection, mealPlans_collection, recipes_collection
from datetime import date, timedelta

router = APIRouter()

def convert_object_ids(doc):
    """
    Recursively converts any ObjectId fields in a MongoDB document to strings.
    """
    if isinstance(doc, list):
        return [convert_object_ids(item) for item in doc]
    elif isinstance(doc, dict):
        return {key: convert_object_ids(value) for key, value in doc.items()}
    elif isinstance(doc, ObjectId):
        return str(doc)
    else:
        return doc


class FromMealPlanRequest(BaseModel):
    user_id: str
    start_date: str  # YYYY-MM-DD
    end_date: str    # YYYY-MM-DD

@router.post("/from-meal-plan")
async def generate_from_meal_plan(body: FromMealPlanRequest):
    try:
        user_obj_id = ObjectId(body.user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user_id")

    # Build list of dates in range
    start = date.fromisoformat(body.start_date)
    end = date.fromisoformat(body.end_date)
    dates = [(start + timedelta(days=i)).isoformat() for i in range((end - start).days + 1)]

    # Fetch all meal plans in range
    plans = await mealPlans_collection.find({
        "user_id": user_obj_id,
        "date": {"$in": dates}
    }).to_list(length=None)

    if not plans:
        return {"added": 0, "message": "No meals planned for this week"}

    # Get unique recipe ids
    recipe_ids = list({str(p["recipe_id"]) for p in plans})

    # Fetch recipes
    recipes = []
    for rid in recipe_ids:
        try:
            r = await recipes_collection.find_one({"_id": ObjectId(rid)})
            if r:
                recipes.append(r)
        except Exception:
            pass

    # Aggregate ingredients
    aggregated = {}  # name.lower() -> {name, quantity, unit, category}
    for recipe in recipes:
        for ing in recipe.get("ingredients", []):
            key = ing.get("name", "").strip().lower()
            if not key:
                continue
            if key in aggregated:
                # Try to combine quantities numerically
                try:
                    existing_qty = float(aggregated[key]["quantity"] or 0)
                    new_qty = float(ing.get("quantity") or 0)
                    aggregated[key]["quantity"] = str(existing_qty + new_qty)
                except (ValueError, TypeError):
                    pass  # Keep existing if can't combine
            else:
                aggregated[key] = {
                    "name": ing.get("name", "").strip(),
                    "quantity": str(ing.get("quantity", "")) if ing.get("quantity") else "",
                    "unit": ing.get("unit", "") or "",
                    "category": "other",
                    "checked": False,
                }

    if not aggregated:
        return {"added": 0, "message": "Recipes have no ingredients"}

    # Find or create grocery list
    grocery_list = await grocery_collection.find_one({"user_id": user_obj_id})
    if not grocery_list:
        result = await grocery_collection.insert_one({
            "user_id": user_obj_id,
            "name": "My List",
            "items": []
        })
        grocery_list = await grocery_collection.find_one({"_id": result.inserted_id})

    list_id = grocery_list["_id"]
    existing_names = {i.get("name", "").lower() for i in grocery_list.get("items", [])}

    # Add only items not already in the list
    new_items = [v for k, v in aggregated.items() if k not in existing_names]

    if new_items:
        await grocery_collection.update_one(
            {"_id": list_id},
            {"$push": {"items": {"$each": new_items}}}
        )

    return {"added": len(new_items), "skipped": len(aggregated) - len(new_items)}


# Create a new grocery list
@router.post("/")
def create_grocery_list(grocery: GroceryList):
    grocery_dict = grocery.dict(by_alias=True)
    grocery_dict["user_id"] = ObjectId(grocery_dict["user_id"])
    result = grocery_collection.insert_one(grocery_dict)
    if not result:
        raise HTTPException(status_code=500, detail="Failed to create grocery list")
    else:
        return {"message": "List created"}
    

@router.get("/userID/{user_id}")
async def get_grocery_lists_userID(user_id: str):
    try:
        user_obj_id = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=404, detail="Invalid user ID format")
    
    grocery_lists = await grocery_collection.find({"user_id": user_obj_id}).to_list(length=100)

    return convert_object_ids(grocery_lists)
    
    

# Get a grocery list by its ID
@router.get("/listID/{grocery_list_id}")
async def get_grocery_list_listID(grocery_list_id: str):
    try:
        obj_id = ObjectId(grocery_list_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid grocery list ID format")

    grocery_list = await grocery_collection.find_one({"_id": obj_id})
    if not grocery_list:
        raise HTTPException(status_code=404, detail="Grocery list not found")

    return convert_object_ids(grocery_list)

# Add a new grocery item to the list (or update quantity if item exists)
@router.put("/{grocery_list_id}")
async def add_grocery_item(grocery_list_id: str, item: GroceryItem):
    grocery_list = await grocery_collection.find_one({"_id": ObjectId(grocery_list_id)})
    if not grocery_list:
        raise HTTPException(status_code=404, detail="Grocery list not found")

    # Check if item with the same name already exists
    existing_items = grocery_list.get("items", [])
    for existing_item in existing_items:
        if existing_item.get("name") == item.name:
            new_quantity = int(existing_item.get("quantity", 1)) + int(item.quantity)
            result = await grocery_collection.update_one(
                {"_id": ObjectId(grocery_list_id), "items.name": item.name},
                {"$set": {"items.$.quantity": new_quantity}}
            )
            return {"message": f"Updated quantity of '{item.name}' to {new_quantity}"}

    # If item doesn't exist, add it to the list
    item_dict = item.dict(by_alias=True)
    result = await grocery_collection.update_one(
        {"_id": ObjectId(grocery_list_id)},
        {"$push": {"items": item_dict}}
    )
    return {"message": f"Added new item '{item.name}'", "item": item_dict}

# Toggle checked state of an item
@router.patch("/{grocery_list_id}/{item_name}/check")
async def toggle_grocery_item(grocery_list_id: str, item_name: str):
    grocery_list = await grocery_collection.find_one({"_id": ObjectId(grocery_list_id)})
    if not grocery_list:
        raise HTTPException(status_code=404, detail="Grocery list not found")
    items = grocery_list.get("items", [])
    current = next((i for i in items if i.get("name") == item_name), None)
    if current is None:
        raise HTTPException(status_code=404, detail="Item not found")
    new_checked = not current.get("checked", False)
    await grocery_collection.update_one(
        {"_id": ObjectId(grocery_list_id), "items.name": item_name},
        {"$set": {"items.$.checked": new_checked}}
    )
    return {"checked": new_checked}


# Delete a grocery item by name from the list
@router.delete("/{grocery_list_id}/{item_name}")
async def delete_grocery_item(grocery_list_id: str, item_name: str):
    grocery_list = await grocery_collection.find_one({"_id": ObjectId(grocery_list_id)})
    if not grocery_list:
        raise HTTPException(status_code=404, detail="Grocery list not found")
    
    result = await grocery_collection.update_one(
        {"_id": ObjectId(grocery_list_id)},
        {"$pull": {"items": {"name": item_name}}}
    )

    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail=f"Item '{item_name}' not found in grocery list")

    return {"message": f"Item '{item_name}' deleted from grocery list"}


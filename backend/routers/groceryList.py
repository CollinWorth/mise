from fastapi import APIRouter, HTTPException
from model import GroceryList, GroceryItem
from bson import ObjectId
from database import grocery_collection

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


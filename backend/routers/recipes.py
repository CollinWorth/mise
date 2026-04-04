from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import mealPlans_collection, recipes_collection
from model import Recipe


router = APIRouter()

def recipe_to_json(recipe):
    recipe = dict(recipe)
    if "_id" in recipe:
        recipe["_id"] = str(recipe["_id"])
    if "user_id" in recipe and isinstance(recipe["user_id"], ObjectId):
        recipe["user_id"] = str(recipe["user_id"])
    # If you have ObjectId in ingredients, convert those too
    if "ingredients" in recipe:
        for ing in recipe["ingredients"]:
            if "recipe_id" in ing and isinstance(ing["recipe_id"], ObjectId):
                ing["recipe_id"] = str(ing["recipe_id"])
    return recipe

@router.get("/")
async def get_recipes():
    recipes = await recipes_collection.find().to_list(1000)
    return recipes

@router.post("/")
async def create_recipe(recipe: Recipe):
    try:
        # Convert user_id to ObjectId
        recipe_dict = recipe.dict()
        try:
            recipe_dict["user_id"] = ObjectId(recipe_dict["user_id"])
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid user_id format")

        # Insert the recipe into the database
        await recipes_collection.insert_one(recipe_dict)
        return {"message": "Recipe created successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creating recipe: {str(e)}")

@router.get("/user/{user_id}")
async def get_recipes_by_user(user_id: str):
    try:
        user_obj_id = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user_id format")
    try:
        recipes = await recipes_collection.find({"user_id": user_obj_id}).to_list(1000)
        # Convert ObjectId fields to strings
        return [recipe_to_json(r) for r in recipes]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching recipes: {str(e)}")

@router.get("/{recipe_id}")
async def get_recipe(recipe_id: str):
    try:
        recipe = await recipes_collection.find_one({"_id": ObjectId(recipe_id)})
        if not recipe:
            raise HTTPException(status_code=404, detail="Recipe not found")
        return recipe_to_json(recipe)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching recipe: {str(e)}")

@router.delete("/deleteRecipe/{recipe_id}")
async def delete_recipe(recipe_id: str):
    try:
        resulte = await recipes_collection.find_one_and_delete({"_id": ObjectId(recipe_id)})
        if not resulte:
            raise HTTPException(status_code=404, detail="Recipe not found")
        return {"message": "Recipe deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting recipe: {str(e)}")

@router.post("/{recipe_id}/{selected_day}/{user_id}")
async def select_recipe(recipe_id: str, selected_day: str, user_id: str):
    try:
        recipe_obj_id = ObjectId(recipe_id)
        user_obj_id = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid recipe_id or user_id format")

    try:
        # Update the recipe with the selected day and user
        result = await mealPlans_collection.insert_one(
            {
                "user_id": user_obj_id,
                "recipe_id": recipe_obj_id,
                "date": selected_day
            }
        )
        return {"message": "Recipe selected successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error selecting recipe: {str(e)}")


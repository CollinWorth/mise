from fastapi import APIRouter, HTTPException
from bson import ObjectId
from database import mealPlans_collection 

router = APIRouter()

@router.get("/{date}/{userId}")
async def get_meal_plans(date: str, userId: str):
    try:
        print(f"Fetching meal plans for date: {date}, userId: {userId}")  # Debugging

        # Convert userId to ObjectId
        try:
            user_obj_id = ObjectId(userId)
        except Exception as e:
            print(f"Invalid userId format: {userId}")  # Debugging
            raise HTTPException(status_code=400, detail="Invalid userId format")

        # Query the database
        meal_plans = await mealPlans_collection.find({"user_id": user_obj_id, "date": date}).to_list(length=None)

        # Convert ObjectId fields to strings
        def convert_objectid_to_string(document):
            document["_id"] = str(document["_id"])
            document["user_id"] = str(document["user_id"])
            document["recipe_id"] = str(document["recipe_id"])
            return document

        meal_plans = [convert_objectid_to_string(meal) for meal in meal_plans]

        print(f"Meal plans fetched: {meal_plans}")  # Debugging
        return meal_plans
    except Exception as e:
        print(f"Error fetching meal plans: {str(e)}")  # Debugging
        raise HTTPException(status_code=500, detail=f"Failed to fetch meal plans: {str(e)}")

@router.post("/Create/{date}/{userId}/{recipeId}")
async def create_meal_plan(date: str, userId: str, recipeId: str):
    try:
        user_obj_id = ObjectId(userId)
        recipe_obj_id = ObjectId(recipeId)

        # Insert the meal plan into the database
        result = await mealPlans_collection.insert_one({
            "user_id": user_obj_id,
            "recipe_id": recipe_obj_id,
            "date": date
        })

        # Fetch the inserted document to return it
        new_meal_plan = await mealPlans_collection.find_one({"_id": result.inserted_id})

        # Convert ObjectId fields to strings
        def convert_objectid_to_string(document):
            document["_id"] = str(document["_id"])
            document["user_id"] = str(document["user_id"])
            document["recipe_id"] = str(document["recipe_id"])
            return document

        return convert_objectid_to_string(new_meal_plan)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create meal plan: {str(e)}")

@router.delete("/Delete/{mealPlanId}")
async def delete_meal_plan(mealPlanId: str):
    try:
        # Convert mealPlanId to ObjectId
        try:
            meal_plan_obj_id = ObjectId(mealPlanId)
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid mealPlanId format")

        # Delete the meal plan from the database
        result = await mealPlans_collection.find_one_and_delete({"_id": meal_plan_obj_id})
        if not result:
            raise HTTPException(status_code=404, detail="Meal plan not found")
        return {"message": "Meal plan deleted successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete meal plan: {str(e)}")
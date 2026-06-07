from fastapi import HTTPException
import motor.motor_asyncio
import os
from dotenv import load_dotenv
from bson import ObjectId
from bson.errors import InvalidId

# Load environment variables from .env file
load_dotenv()

uri = os.getenv("MONGODB_URI")
db_name = os.getenv("DATABASE_NAME", "cookindb")
client = motor.motor_asyncio.AsyncIOMotorClient(uri)
db = client[db_name]
recipes_collection    = db.recipes
users_collection      = db.users
mealPlans_collection  = db.mealPlans
grocery_collection    = db.groceryLists
follows_collection    = db.follows
comments_collection   = db.comments
ratings_collection    = db.ratings
images_collection     = db.images


def parse_object_id(value, name: str = "id") -> ObjectId:
    """Parse a string into an ObjectId, raising 400 (not 500) on malformed input."""
    try:
        return ObjectId(value)
    except (InvalidId, TypeError):
        raise HTTPException(status_code=400, detail=f"Invalid {name}")


#mongosh "mongodb+srv://cookindb.wcbu46g.mongodb.net/" --apiVersion 1 --username collin

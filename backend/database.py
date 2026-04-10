from fastapi import FastAPI
import motor.motor_asyncio
import os
from dotenv import load_dotenv

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




#mongosh "mongodb+srv://cookindb.wcbu46g.mongodb.net/" --apiVersion 1 --username collin

from fastapi import FastAPI
from database import client, db
from routers import users, recipes, mealPlans, groceryList
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.include_router(recipes.router, prefix="/recipes", tags=["recipes"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(mealPlans.router, prefix="/mealPlans", tags=["mealPlans"])
app.include_router(groceryList.router, prefix="/groceryList", tags=["groceryList"])

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # frontend origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_db_client():
    try:
        await client.admin.command('ping')
        print("MongoDB connection successful")
    except Exception as e:
        print(f"MongoDB connection failed: {e}")

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
    print("MongoDB connection closed")

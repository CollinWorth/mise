from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List


class Ingredient(BaseModel):
    name: str
    quantity: str
    unit: str 


class Recipe(BaseModel):
    recipe_name: str
    ingredients: List[Ingredient]
    instructions: Optional[str]
    prep_time: Optional[int] = Field(default=None, title="Preparation Time in minutes")
    cook_time: Optional[int] = Field(default=None, title="Cooking Time in minutes")
    servings: Optional[int] = Field(default=None, title="Number of Servings")
    cuisine: Optional[str] = Field(default=None, title="Cuisine Type")
    tags: Optional[str] = Field(default=None, title="Tags for the Recipe")
    image_url: Optional[str] = Field(default=None, title="Image URL for the Recipe")
    user_id: str

class GroceryItem(BaseModel):
    name: str
    quantity: str
    category: str
    checked: bool = False

class GroceryList(BaseModel):
    user_id: str
    name: str
    items: List[GroceryItem] = []

    class Config:
        allow_population_by_field_name = True
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
    category: Optional[str] = Field(default=None, title="Dish category, e.g. Soup, Salad, Pasta")
    tags: Optional[str] = Field(default=None, title="Attribute tags, e.g. quick, healthy, vegan")
    image_url: Optional[str] = Field(default=None, title="Image URL for the Recipe")
    is_public: bool = False
    like_count: int = 0
    user_id: str
    original_recipe_id: Optional[str] = None
    original_author_name: Optional[str] = None
    is_modified: bool = False

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
import asyncio
import httpx

BASE = "http://localhost:8000"

USER = {"name": "Collin", "email": "collin@mise.com", "password": "password123"}

RECIPES = [
    {
        "recipe_name": "Spaghetti Carbonara",
        "cuisine": "Italian",
        "tags": "pasta, quick",
        "prep_time": 10,
        "cook_time": 20,
        "servings": 4,
        "image_url": "https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800",
        "ingredients": [
            {"name": "Spaghetti", "quantity": "400", "unit": "g"},
            {"name": "Pancetta", "quantity": "200", "unit": "g"},
            {"name": "Eggs", "quantity": "4", "unit": ""},
            {"name": "Parmesan", "quantity": "100", "unit": "g"},
            {"name": "Black pepper", "quantity": "1", "unit": "tsp"},
        ],
        "instructions": "Cook spaghetti in salted boiling water until al dente.\nFry pancetta until crispy.\nWhisk eggs and parmesan together.\nDrain pasta, reserving 1 cup pasta water.\nCombine pasta and pancetta off heat, add egg mixture, toss quickly adding pasta water as needed.\nSeason with black pepper and serve immediately.",
    },
    {
        "recipe_name": "Chicken Tikka Masala",
        "cuisine": "Indian",
        "tags": "curry, comfort food",
        "prep_time": 20,
        "cook_time": 40,
        "servings": 4,
        "image_url": "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800",
        "ingredients": [
            {"name": "Chicken breast", "quantity": "700", "unit": "g"},
            {"name": "Yogurt", "quantity": "1", "unit": "cup"},
            {"name": "Tikka masala paste", "quantity": "3", "unit": "tbsp"},
            {"name": "Crushed tomatoes", "quantity": "400", "unit": "g"},
            {"name": "Heavy cream", "quantity": "200", "unit": "ml"},
            {"name": "Garlic", "quantity": "4", "unit": "cloves"},
            {"name": "Ginger", "quantity": "1", "unit": "inch"},
        ],
        "instructions": "Marinate chicken in yogurt and tikka paste for at least 1 hour.\nGrill or broil chicken until charred, set aside.\nSauté garlic and ginger, add remaining tikka paste.\nAdd crushed tomatoes and simmer 15 minutes.\nStir in cream, add chicken, simmer 10 more minutes.\nServe with basmati rice and naan.",
    },
    {
        "recipe_name": "Smash Burgers",
        "cuisine": "American",
        "tags": "burgers, weekend",
        "prep_time": 10,
        "cook_time": 15,
        "servings": 4,
        "image_url": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800",
        "ingredients": [
            {"name": "Ground beef 80/20", "quantity": "700", "unit": "g"},
            {"name": "Brioche buns", "quantity": "4", "unit": ""},
            {"name": "American cheese", "quantity": "8", "unit": "slices"},
            {"name": "White onion", "quantity": "1", "unit": ""},
            {"name": "Pickles", "quantity": "12", "unit": "slices"},
            {"name": "Special sauce", "quantity": "4", "unit": "tbsp"},
        ],
        "instructions": "Divide beef into 4 loose balls, don't pack them.\nHeat cast iron skillet over high heat until smoking.\nPlace beef ball on skillet, immediately smash flat with a spatula.\nSeason with salt and pepper, cook 2 minutes.\nFlip, add cheese, cook 1 more minute.\nToast buns, assemble with sauce, onion, pickles.",
    },
    {
        "recipe_name": "Avocado Toast",
        "cuisine": "American",
        "tags": "breakfast, quick, vegetarian",
        "prep_time": 5,
        "cook_time": 5,
        "servings": 2,
        "image_url": "https://images.unsplash.com/photo-1541519227354-08fa5d50c820?w=800",
        "ingredients": [
            {"name": "Sourdough bread", "quantity": "2", "unit": "slices"},
            {"name": "Ripe avocado", "quantity": "1", "unit": ""},
            {"name": "Lemon juice", "quantity": "1", "unit": "tbsp"},
            {"name": "Red pepper flakes", "quantity": "1", "unit": "pinch"},
            {"name": "Flaky salt", "quantity": "1", "unit": "pinch"},
            {"name": "Eggs", "quantity": "2", "unit": ""},
        ],
        "instructions": "Toast sourdough until golden.\nMash avocado with lemon juice, salt and pepper.\nFry eggs to your liking.\nSpread avocado on toast, top with egg.\nFinish with red pepper flakes and flaky salt.",
    },
    {
        "recipe_name": "Beef Tacos",
        "cuisine": "Mexican",
        "tags": "tacos, weeknight",
        "prep_time": 10,
        "cook_time": 20,
        "servings": 4,
        "image_url": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800",
        "ingredients": [
            {"name": "Ground beef", "quantity": "500", "unit": "g"},
            {"name": "Taco seasoning", "quantity": "2", "unit": "tbsp"},
            {"name": "Corn tortillas", "quantity": "12", "unit": ""},
            {"name": "White onion", "quantity": "1", "unit": ""},
            {"name": "Cilantro", "quantity": "1", "unit": "bunch"},
            {"name": "Lime", "quantity": "2", "unit": ""},
            {"name": "Salsa", "quantity": "1", "unit": "cup"},
        ],
        "instructions": "Brown ground beef in a skillet over medium-high heat.\nDrain excess fat, add taco seasoning and 1/4 cup water.\nSimmer 5 minutes until sauce thickens.\nWarm tortillas on a dry skillet or open flame.\nAssemble tacos with beef, diced onion, cilantro, and salsa.\nServe with lime wedges.",
    },
    {
        "recipe_name": "Miso Ramen",
        "cuisine": "Japanese",
        "tags": "soup, noodles, comfort",
        "prep_time": 15,
        "cook_time": 30,
        "servings": 2,
        "image_url": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=800",
        "ingredients": [
            {"name": "Ramen noodles", "quantity": "200", "unit": "g"},
            {"name": "Chicken broth", "quantity": "1", "unit": "L"},
            {"name": "White miso paste", "quantity": "3", "unit": "tbsp"},
            {"name": "Soy sauce", "quantity": "2", "unit": "tbsp"},
            {"name": "Soft boiled eggs", "quantity": "2", "unit": ""},
            {"name": "Green onions", "quantity": "3", "unit": ""},
            {"name": "Nori", "quantity": "2", "unit": "sheets"},
            {"name": "Corn", "quantity": "1", "unit": "cup"},
        ],
        "instructions": "Bring broth to a simmer, whisk in miso paste and soy sauce.\nCook ramen noodles separately per package instructions.\nSoft boil eggs for 6.5 minutes, peel and halve.\nDivide noodles between bowls, ladle hot broth over.\nTop with egg, corn, green onions, and nori.",
    },
    {
        "recipe_name": "Margherita Pizza",
        "cuisine": "Italian",
        "tags": "pizza, vegetarian",
        "prep_time": 90,
        "cook_time": 12,
        "servings": 2,
        "image_url": "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800",
        "ingredients": [
            {"name": "Pizza dough", "quantity": "300", "unit": "g"},
            {"name": "San Marzano tomatoes", "quantity": "200", "unit": "g"},
            {"name": "Fresh mozzarella", "quantity": "200", "unit": "g"},
            {"name": "Fresh basil", "quantity": "1", "unit": "bunch"},
            {"name": "Olive oil", "quantity": "2", "unit": "tbsp"},
            {"name": "Salt", "quantity": "1", "unit": "tsp"},
        ],
        "instructions": "Preheat oven to maximum temperature with a pizza stone inside.\nStretch dough into a 12-inch circle.\nCrush tomatoes by hand, spread thinly on dough.\nTear mozzarella and distribute evenly.\nBake 10-12 minutes until crust is charred and cheese is bubbly.\nTop with fresh basil and a drizzle of olive oil.",
    },
    {
        "recipe_name": "Greek Salad",
        "cuisine": "Greek",
        "tags": "salad, healthy, vegetarian",
        "prep_time": 15,
        "cook_time": 0,
        "servings": 4,
        "image_url": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=800",
        "ingredients": [
            {"name": "Cucumber", "quantity": "1", "unit": "large"},
            {"name": "Cherry tomatoes", "quantity": "250", "unit": "g"},
            {"name": "Red onion", "quantity": "1", "unit": "small"},
            {"name": "Kalamata olives", "quantity": "100", "unit": "g"},
            {"name": "Feta cheese", "quantity": "200", "unit": "g"},
            {"name": "Olive oil", "quantity": "3", "unit": "tbsp"},
            {"name": "Oregano", "quantity": "1", "unit": "tsp"},
        ],
        "instructions": "Chop cucumber into chunks, halve tomatoes, thinly slice red onion.\nCombine vegetables and olives in a large bowl.\nPlace block of feta on top.\nDrizzle generously with olive oil, sprinkle oregano and salt.\nDo not toss — serve as is and mix at the table.",
    },
]


async def seed():
    async with httpx.AsyncClient() as client:
        # Register user
        print("Creating user...")
        r = await client.post(f"{BASE}/users/", json=USER)
        if r.status_code == 400:
            print("User already exists, logging in...")
        elif r.status_code == 200:
            print("User created.")
        else:
            print(f"Unexpected status: {r.status_code} {r.text}")

        # Login
        print("Logging in...")
        r = await client.post(f"{BASE}/users/login", json={"email": USER["email"], "password": USER["password"]})
        if r.status_code != 200:
            print(f"Login failed: {r.text}")
            return
        data = r.json()
        token = data["access_token"]
        user_id = data["user"]["id"]
        print(f"Logged in as {data['user']['name']} (id: {user_id})")

        headers = {"Authorization": f"Bearer {token}"}

        # Add recipes
        for recipe in RECIPES:
            recipe["user_id"] = user_id
            r = await client.post(f"{BASE}/recipes/", json=recipe, headers=headers)
            if r.status_code == 200:
                print(f"  ✓ {recipe['recipe_name']}")
            else:
                print(f"  ✗ {recipe['recipe_name']}: {r.text}")

        print("\nDone! Login with:")
        print(f"  Email:    {USER['email']}")
        print(f"  Password: {USER['password']}")


asyncio.run(seed())

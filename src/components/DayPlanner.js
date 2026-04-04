import React, { useState, useEffect } from 'react';
import './css/DayPlanner.css';
import SearchBar from '../components/SearchBar.js';

function DayPlanner({ user, recipes, selectedDay, setSelectedDay, selectedWeek, selectedDate, setSelectedDate }) {
  const daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const [dayRecipes, setDayRecipes] = useState([]);
  const [allUserRecipes, setAllUserRecipes] = useState([]); // Holds all recipes for the user
  const [searchQuery, setSearchQuery] = useState('');
  const [filteredRecipes, setFilteredRecipes] = useState([]);

  // Fetch recipes for the selected day
  useEffect(() => {
    const fetchDayMeals = async () => {
      try {
        const formattedDate = new Date(selectedDate).toISOString().split('T')[0];

        const response = await fetch(
          `http://localhost:8000/mealPlans/${formattedDate}/${user.id || user._id}`
        );

        if (response.ok) {
          const mealPlans = await response.json();

          // Check if mealPlans is empty
          if (!mealPlans || mealPlans.length === 0) {
            console.log('No meal plans found for the selected date.');
            setDayRecipes([]); // Clear the dayRecipes state
            return;
          }

          // Fetch detailed recipe information for each meal plan
          const recipePromises = mealPlans.map(async (meal) => {
            const recipeResponse = await fetch(`http://localhost:8000/recipes/${meal.recipe_id}`);
            if (recipeResponse.ok) {
              const recipe = await recipeResponse.json();
              return { ...recipe, mealPlanId: meal._id }; // Include the meal plan's _id
            } else {
              console.error(`Failed to fetch recipe with ID ${meal.recipe_id}`);
              return null; // Handle failed recipe fetch
            }
          });

          const recipesWithIds = (await Promise.all(recipePromises)).filter(Boolean); // Filter out null values

          setDayRecipes(recipesWithIds); // Store recipes with meal plan IDs
        } else {
          console.error('Failed to fetch day meals:', response.statusText);
          setDayRecipes([]); // Clear the dayRecipes state on failure
        }
      } catch (error) {
        console.error('Error fetching day meals:', error);
        setDayRecipes([]); // Clear the dayRecipes state on error
      }
    };

    if (selectedDate && user) {
      fetchDayMeals();
    }
  }, [selectedDate, user]);

  // Fetch all recipes for the user
  useEffect(() => {
    const fetchAllUserRecipes = async () => {
      try {
        const response = await fetch(`http://localhost:8000/recipes/user/${user.id || user._id}`);
        if (response.ok) {
          const recipes = await response.json();
          setAllUserRecipes(recipes); // Store all user-associated recipes
          setFilteredRecipes(recipes); // Initialize filtered recipes
        } else {
          console.error('Failed to fetch user recipes:', response.statusText);
        }
      } catch (error) {
        console.error('Error fetching user recipes:', error);
      }
    };

    if (user) {
      fetchAllUserRecipes();
    }
  }, [user]);

  // Filter recipes based on the search query
  useEffect(() => {
    setFilteredRecipes(
      allUserRecipes.filter((recipe) =>
        recipe.recipe_name.toLowerCase().includes(searchQuery.toLowerCase())
      )
    );
  }, [searchQuery, allUserRecipes]);

  const handleDragStart = (event, recipe) => {
    console.log('Dragging recipe:', recipe); // Debugging
    event.dataTransfer.setData('recipe', JSON.stringify(recipe));
  };

  const handleDrop = async (event) => {
    event.preventDefault();
    const recipe = JSON.parse(event.dataTransfer.getData('recipe'));
    console.log('Dropped recipe:', recipe); // Debugging

    const formattedDate = new Date(selectedDate).toISOString().split('T')[0]; // Format date to YYYY-MM-DD

    try {
      const response = await fetch(
        `http://localhost:8000/mealPlans/Create/${formattedDate}/${user.id || user._id}/${recipe._id}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ recipe_id: recipe.id, date: formattedDate }),
        }
      );

      if (response.ok) {
        const newMealPlan = await response.json(); // Get the newly created meal plan from the backend
        console.log('Meal plan created successfully:', newMealPlan);

        // Add the new meal plan to the state
        setDayRecipes((prev) => [
          ...prev,
          { ...recipe, mealPlanId: newMealPlan._id } // Include the mealPlanId from the backend
        ]);
      } else {
        console.error('Failed to create meal plan:', response.statusText);
      }
    } catch (error) {
      console.error('Error creating meal plan:', error);
    }
  };

  const handleDragOver = (event) => {
    event.preventDefault();
  };

  const removeRecipe = async (mealPlanId) => {
    try {
      console.log('Removing recipe with mealPlanId:', mealPlanId); // Debugging
      const response = await fetch(
        `http://localhost:8000/mealPlans/Delete/${mealPlanId}`,
        {
          method: 'DELETE',
        }
      );

      if (response.ok) {
        setDayRecipes((prev) => prev.filter((recipe) => recipe.mealPlanId !== mealPlanId)); // Remove the recipe from the list
        console.log('Meal plan deleted successfully');
      } else {
        console.error('Failed to delete meal plan:', response.statusText);
      }
    } catch (error) {
      console.error('Error deleting meal plan:', error);
    }
  };

  const handleDayButtonClick = (day, index) => {
    setSelectedDay(day);

    // Calculate the date for the selected day based on the current week
    const startOfWeek = new Date(selectedDate);
    startOfWeek.setDate(selectedDate.getDate() - selectedDate.getDay()); // Get Sunday of the current week
    const newSelectedDate = new Date(startOfWeek);
    newSelectedDate.setDate(startOfWeek.getDate() + index); // Add the day index to Sunday

    setSelectedDate(newSelectedDate); // Update the selectedDate state
  };

  return (
    <div className="day-planner">
      {/* Tabs for switching between days */}
      <div className="day-selector">
        {daysOfWeek.map((day, index) => (
          <button
            key={day}
            className={`day-button ${selectedDay === day ? 'active' : ''}`}
            onClick={() => handleDayButtonClick(day, index)}
          >
            {day}
          </button>
        ))}
      </div>

      {/* Current day's meal plan */}
      <div className="day-recipes" onDragOver={handleDragOver} onDrop={handleDrop}>
        <h2>Meal Plan for {selectedDay} ({selectedWeek})</h2>
        {dayRecipes.length > 0 ? (
          <ul>
            {dayRecipes.map((recipe, idx) => (
              <li key={idx} className="recipe-item">
                <img
                  src={recipe.image_url}
                  alt={recipe.recipe_name}
                  style={{ width: '100px', height: '100px', objectFit: 'cover' }}
                />
                <span className="recipe-name">{recipe.recipe_name}</span>
                <span className="recipe-cuisine">Cuisine: {recipe.cuisine}</span>
                <span className="recipe-tags">Tags: {recipe.tags}</span>
                <button
                  className="remove-recipe"
                  onClick={() => removeRecipe(recipe.mealPlanId)}
                >
                  X
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="empty-drop-zone">
            No recipes assigned to this day. 
            <br />
            Drag and drop a recipe here to add it.
          </p>
        )}
      </div>

      {/* Search feature */}
      <div className="search-bar">
        <h2>Search Recipes</h2>
        <SearchBar onSearch={(query) => setSearchQuery(query)} />
        <ul className="search-results">
          {filteredRecipes.map((recipe, idx) => (
            <li
              key={idx}
              className="search-item"
              draggable
              onDragStart={(event) => handleDragStart(event, recipe)}
            >
              <img
                src={recipe.image_url}
                alt={recipe.recipe_name}
                style={{ width: '100px', height: '100px', objectFit: 'cover' }}
              />
              <span className="recipe-name">{recipe.recipe_name}</span>
              <span className="recipe-cuisine">Cuisine: {recipe.cuisine}</span>
              <span className="recipe-tags">Tags: {recipe.tags}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default DayPlanner;
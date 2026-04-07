import React, { useState, useEffect } from 'react';
import { apiFetch } from '../api';
import './css/DayPlanner.css';
import SearchBar from '../components/SearchBar.js';

function DayPlanner({ user, recipes, selectedDay, setSelectedDay, selectedWeek, selectedDate, setSelectedDate }) {
  const daysOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const [dayRecipes, setDayRecipes] = useState([]);
  const [allUserRecipes, setAllUserRecipes] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [filteredRecipes, setFilteredRecipes] = useState([]);

  useEffect(() => {
    const fetchDayMeals = async () => {
      try {
        const formattedDate = new Date(selectedDate).toISOString().split('T')[0];
        const response = await apiFetch(`/mealPlans/${formattedDate}/${user.id || user._id}`);
        if (response.ok) {
          const mealPlans = await response.json();
          if (!mealPlans || mealPlans.length === 0) { setDayRecipes([]); return; }
          const recipePromises = mealPlans.map(async (meal) => {
            const r = await apiFetch(`/recipes/${meal.recipe_id}`);
            if (r.ok) return { ...(await r.json()), mealPlanId: meal._id };
            return null;
          });
          setDayRecipes((await Promise.all(recipePromises)).filter(Boolean));
        } else {
          setDayRecipes([]);
        }
      } catch (error) {
        setDayRecipes([]);
      }
    };
    if (selectedDate && user) fetchDayMeals();
  }, [selectedDate, user]);

  useEffect(() => {
    const fetchAllUserRecipes = async () => {
      try {
        const response = await apiFetch(`/recipes/user/${user.id || user._id}`);
        if (response.ok) {
          const data = await response.json();
          setAllUserRecipes(data);
          setFilteredRecipes(data);
        }
      } catch (error) {
        console.error('Error fetching user recipes:', error);
      }
    };
    if (user) fetchAllUserRecipes();
  }, [user]);

  useEffect(() => {
    setFilteredRecipes(
      allUserRecipes.filter((r) =>
        r.recipe_name.toLowerCase().includes(searchQuery.toLowerCase())
      )
    );
  }, [searchQuery, allUserRecipes]);

  const handleDragStart = (event, recipe) => {
    event.dataTransfer.setData('recipe', JSON.stringify(recipe));
  };

  const handleDrop = async (event) => {
    event.preventDefault();
    const recipe = JSON.parse(event.dataTransfer.getData('recipe'));
    const formattedDate = new Date(selectedDate).toISOString().split('T')[0];
    try {
      const response = await apiFetch(
        `/mealPlans/Create/${formattedDate}/${user.id || user._id}/${recipe._id}`,
        { method: 'POST', body: JSON.stringify({ recipe_id: recipe._id, date: formattedDate }) }
      );
      if (response.ok) {
        const newMealPlan = await response.json();
        setDayRecipes((prev) => [...prev, { ...recipe, mealPlanId: newMealPlan._id }]);
      }
    } catch (error) {
      console.error('Error creating meal plan:', error);
    }
  };

  const removeRecipe = async (mealPlanId) => {
    try {
      const response = await apiFetch(`/mealPlans/Delete/${mealPlanId}`, { method: 'DELETE' });
      if (response.ok) setDayRecipes((prev) => prev.filter((r) => r.mealPlanId !== mealPlanId));
    } catch (error) {
      console.error('Error deleting meal plan:', error);
    }
  };

  const handleDayButtonClick = (day, index) => {
    setSelectedDay(day);
    const startOfWeek = new Date(selectedDate);
    startOfWeek.setDate(selectedDate.getDate() - selectedDate.getDay());
    const newDate = new Date(startOfWeek);
    newDate.setDate(startOfWeek.getDate() + index);
    setSelectedDate(newDate);
  };

  return (
    <div className="day-planner">
      <div className="day-selector">
        {daysOfWeek.map((day, index) => (
          <button
            key={day}
            className={`day-button${selectedDay === day ? ' active' : ''}`}
            onClick={() => handleDayButtonClick(day, index)}
          >
            {day}
          </button>
        ))}
      </div>

      <div className="day-recipes" onDragOver={(e) => e.preventDefault()} onDrop={handleDrop}>
        <h2>Meal Plan for {selectedDay} {selectedWeek && `(${selectedWeek})`}</h2>
        {dayRecipes.length > 0 ? (
          <ul>
            {dayRecipes.map((recipe, idx) => (
              <li key={idx} className="recipe-item">
                {recipe.image_url && (
                  <img src={recipe.image_url} alt={recipe.recipe_name} style={{ width: 60, height: 60, objectFit: 'cover', borderRadius: 4 }} />
                )}
                <span className="recipe-name">{recipe.recipe_name}</span>
                {recipe.cuisine && <span className="recipe-cuisine">{recipe.cuisine}</span>}
                <button className="remove-recipe" onClick={() => removeRecipe(recipe.mealPlanId)}>✕</button>
              </li>
            ))}
          </ul>
        ) : (
          <p className="empty-drop-zone">Drag a recipe here to add it.</p>
        )}
      </div>

      <div className="planner-search">
        <h2>Recipes</h2>
        <SearchBar onSearch={(q) => setSearchQuery(q)} />
        <ul className="search-results">
          {filteredRecipes.map((recipe, idx) => (
            <li
              key={idx}
              className="search-item"
              draggable
              onDragStart={(e) => handleDragStart(e, recipe)}
            >
              {recipe.image_url && (
                <img src={recipe.image_url} alt={recipe.recipe_name} style={{ width: 40, height: 40, objectFit: 'cover', borderRadius: 4 }} />
              )}
              <span className="recipe-name">{recipe.recipe_name}</span>
              {recipe.cuisine && <span className="recipe-cuisine">{recipe.cuisine}</span>}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default DayPlanner;

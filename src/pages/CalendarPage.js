import React, { useState, useEffect } from 'react';
import { apiFetch } from '../api';
import './css/Calendar.css';

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTH_NAMES = ['January','February','March','April','May','June','July','August','September','October','November','December'];

function startOfWeek(date) {
  const d = new Date(date);
  d.setDate(d.getDate() - d.getDay());
  d.setHours(0, 0, 0, 0);
  return d;
}

function addDays(date, n) {
  const d = new Date(date);
  d.setDate(d.getDate() + n);
  return d;
}

function formatDate(date) {
  return new Date(date).toISOString().split('T')[0];
}

const CUISINE_EMOJI = {
  italian: '🍝', mexican: '🌮', japanese: '🍱', chinese: '🥡',
  indian: '🍛', american: '🍔', french: '🥐', thai: '🍜',
  mediterranean: '🫒', greek: '🫙',
};
function cuisineEmoji(cuisine) {
  return (cuisine && CUISINE_EMOJI[cuisine.toLowerCase()]) || '🍽';
}

export default function CalendarPage({ user }) {
  const [weekStart, setWeekStart] = useState(() => startOfWeek(new Date()));
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [dayMeals, setDayMeals] = useState([]);
  const [allRecipes, setAllRecipes] = useState([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [adding, setAdding] = useState(null); // recipe id being added

  const weekDays = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
  const today = new Date(); today.setHours(0, 0, 0, 0);

  useEffect(() => {
    if (!user) return;
    apiFetch(`/recipes/user/${user.id || user._id}`)
      .then(r => r.ok ? r.json() : [])
      .then(setAllRecipes)
      .catch(() => {});
  }, [user]);

  useEffect(() => {
    if (!user) return;
    fetchDayMeals();
  }, [selectedDate, user]);

  const fetchDayMeals = async () => {
    const date = formatDate(selectedDate);
    try {
      const r = await apiFetch(`/mealPlans/${date}/${user.id || user._id}`);
      if (!r.ok) { setDayMeals([]); return; }
      const plans = await r.json();
      const recipes = await Promise.all(
        plans.map(p =>
          apiFetch(`/recipes/${p.recipe_id}`)
            .then(r => r.ok ? r.json() : null)
            .then(recipe => recipe ? { ...recipe, mealPlanId: p._id } : null)
        )
      );
      setDayMeals(recipes.filter(Boolean));
    } catch { setDayMeals([]); }
  };

  const addRecipe = async (recipe) => {
    setAdding(recipe._id);
    const date = formatDate(selectedDate);
    try {
      const r = await apiFetch(
        `/mealPlans/Create/${date}/${user.id || user._id}/${recipe._id}`,
        { method: 'POST', body: JSON.stringify({}) }
      );
      if (r.ok) {
        const plan = await r.json();
        setDayMeals(prev => [...prev, { ...recipe, mealPlanId: plan._id }]);
      }
    } catch {}
    setAdding(null);
  };

  const removeMeal = async (mealPlanId) => {
    try {
      const r = await apiFetch(`/mealPlans/Delete/${mealPlanId}`, { method: 'DELETE' });
      if (r.ok) setDayMeals(prev => prev.filter(m => m.mealPlanId !== mealPlanId));
    } catch {}
  };

  const filteredRecipes = allRecipes.filter(r =>
    r.recipe_name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const weekLabel = (() => {
    const end = addDays(weekStart, 6);
    const sm = MONTH_NAMES[weekStart.getMonth()].slice(0, 3);
    const em = MONTH_NAMES[end.getMonth()].slice(0, 3);
    return `${sm} ${weekStart.getDate()} – ${sm !== em ? em + ' ' : ''}${end.getDate()}`;
  })();

  const selectedLabel = (() => {
    const d = new Date(selectedDate); d.setHours(0,0,0,0);
    const diff = Math.round((d - today) / 86400000);
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Tomorrow';
    if (diff === -1) return 'Yesterday';
    return `${DAY_NAMES[d.getDay()]}, ${MONTH_NAMES[d.getMonth()]} ${d.getDate()}`;
  })();

  return (
    <div className="planner-page">
      {/* Week strip */}
      <div className="planner-top">
        <div className="week-nav">
          <button className="week-nav-btn" onClick={() => setWeekStart(addDays(weekStart, -7))}>←</button>
          <span className="week-label">{weekLabel}</span>
          <button className="week-nav-btn" onClick={() => setWeekStart(addDays(weekStart, 7))}>→</button>
        </div>
        <div className="week-strip">
          {weekDays.map((day, i) => {
            const d = new Date(day); d.setHours(0,0,0,0);
            const isSelected = formatDate(d) === formatDate(selectedDate);
            const isToday = formatDate(d) === formatDate(today);
            return (
              <button
                key={i}
                className={`week-day${isSelected ? ' week-day--selected' : ''}${isToday ? ' week-day--today' : ''}`}
                onClick={() => setSelectedDate(new Date(day))}
              >
                <span className="week-day-name">{DAY_NAMES[d.getDay()]}</span>
                <span className="week-day-num">{d.getDate()}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Two-column body */}
      <div className="planner-columns">

        {/* Left — day plan */}
        <div className="planner-left">
          <div className="day-plan-header">
            <h2>{selectedLabel}</h2>
            {dayMeals.length > 0 && (
              <span className="meal-count">{dayMeals.length} planned</span>
            )}
          </div>

          {dayMeals.length === 0 ? (
            <div className="day-plan-empty">
              <span>Nothing planned yet.</span>
              <span>Select a recipe on the right to add it.</span>
            </div>
          ) : (
            <div className="day-plan-list">
              {dayMeals.map((meal, i) => (
                <div key={i} className="day-meal-item">
                  <div className="day-meal-img">
                    {meal.image_url
                      ? <img src={meal.image_url} alt={meal.recipe_name} />
                      : <span>{cuisineEmoji(meal.cuisine)}</span>
                    }
                  </div>
                  <div className="day-meal-info">
                    <span className="day-meal-name">{meal.recipe_name}</span>
                    <span className="day-meal-meta">
                      {meal.cuisine && <span>{meal.cuisine}</span>}
                      {meal.cook_time && <span>{meal.cook_time}m cook</span>}
                    </span>
                  </div>
                  <button className="day-meal-remove" onClick={() => removeMeal(meal.mealPlanId)}>✕</button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right — recipe browser */}
        <div className="planner-right">
          <div className="recipe-browser-header">
            <h2>Recipes</h2>
            <input
              type="search"
              placeholder="Search..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="planner-search"
            />
          </div>

          <div className="recipe-browser">
            {filteredRecipes.map((recipe, i) => {
              const alreadyAdded = dayMeals.some(m => (m._id || m.id) === (recipe._id || recipe.id));
              return (
                <div
                  key={i}
                  className={`browser-card${alreadyAdded ? ' browser-card--added' : ''}`}
                  onClick={() => !alreadyAdded && addRecipe(recipe)}
                >
                  <div className="browser-card-img">
                    {recipe.image_url
                      ? <img src={recipe.image_url} alt={recipe.recipe_name} />
                      : <span className="browser-card-emoji">{cuisineEmoji(recipe.cuisine)}</span>
                    }
                    <div className="browser-card-overlay">
                      {alreadyAdded ? '✓ Added' : adding === recipe._id ? '...' : '+ Add to plan'}
                    </div>
                  </div>
                  <div className="browser-card-body">
                    <span className="browser-card-name">{recipe.recipe_name}</span>
                    <div className="browser-card-meta">
                      {recipe.cuisine && <span className="badge">{recipe.cuisine}</span>}
                      {recipe.cook_time && <span className="browser-card-time">{recipe.cook_time}m</span>}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

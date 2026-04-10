import React, { useState, useEffect, useCallback } from 'react';
import { apiFetch } from '../api';
import './css/Calendar.css';

const DAY_NAMES   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const DAY_FULL    = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
const MONTH_NAMES = ['January','February','March','April','May','June','July','August','September','October','November','December'];

const CUISINE_EMOJI = {
  italian:'🍝', mexican:'🌮', japanese:'🍱', chinese:'🥡',
  indian:'🍛', american:'🍔', french:'🥐', thai:'🍜',
  mediterranean:'🫒', greek:'🫙',
};
const cuisineEmoji = c => (c && CUISINE_EMOJI[c.toLowerCase()]) || '🍽';

function startOfWeek(date) {
  const d = new Date(date);
  d.setDate(d.getDate() - d.getDay());
  d.setHours(0,0,0,0);
  return d;
}
function addDays(date, n) {
  const d = new Date(date);
  d.setDate(d.getDate() + n);
  return d;
}
function fmt(date) { return new Date(date).toISOString().split('T')[0]; }
function sameDay(a, b) { return fmt(a) === fmt(b); }

// ── Mini calendar helpers ────────────────────────────────────
function buildMonth(year, month) {
  const firstDow = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < firstDow; i++) cells.push(new Date(year, month, 1 - firstDow + i));
  for (let i = 1; i <= daysInMonth; i++) cells.push(new Date(year, month, i));
  while (cells.length % 7) cells.push(new Date(cells[cells.length-1].getTime() + 86400000));
  return cells;
}

// ── Main component ───────────────────────────────────────────
export default function CalendarPage({ user }) {
  const today     = new Date(); today.setHours(0,0,0,0);
  const [weekStart, setWeekStart] = useState(() => startOfWeek(today));
  const [selectedDate, setSelectedDate] = useState(today);
  const [weekMeals, setWeekMeals]       = useState({});
  const [allRecipes, setAllRecipes]     = useState([]);
  const [searchQuery, setSearchQuery]   = useState('');
  const [adding, setAdding]             = useState(null);
  const [calYear, setCalYear]           = useState(today.getFullYear());
  const [calMonth, setCalMonth]         = useState(today.getMonth());

  const weekDays = Array.from({length:7}, (_,i) => addDays(weekStart,i));

  // Load recipes
  useEffect(() => {
    if (!user) return;
    apiFetch(`/recipes/user/${user.id || user._id}`)
      .then(r => r.ok ? r.json() : []).then(setAllRecipes).catch(()=>{});
  }, [user]);

  // Load all 7 days when week changes
  const loadWeek = useCallback(async () => {
    if (!user) return;
    const uid = user.id || user._id;
    const entries = await Promise.all(
      weekDays.map(async day => {
        const date = fmt(day);
        try {
          const r = await apiFetch(`/mealPlans/${date}/${uid}`);
          if (!r.ok) return [date, []];
          const plans = await r.json();
          const meals = await Promise.all(plans.map(p =>
            apiFetch(`/recipes/${p.recipe_id}`)
              .then(r => r.ok ? r.json() : null)
              .then(rec => rec ? {...rec, mealPlanId: p._id} : null)
          ));
          return [date, meals.filter(Boolean)];
        } catch { return [date, []]; }
      })
    );
    setWeekMeals(Object.fromEntries(entries));
  }, [weekStart, user]); // eslint-disable-line

  useEffect(() => { loadWeek(); }, [loadWeek]);

  const selectDay = (day) => {
    const d = new Date(day); d.setHours(0,0,0,0);
    setSelectedDate(d);
    // Keep mini cal in sync
    setCalYear(d.getFullYear());
    setCalMonth(d.getMonth());
    // Navigate week if day is outside current week
    const ws = startOfWeek(d);
    if (fmt(ws) !== fmt(weekStart)) setWeekStart(ws);
  };

  const addRecipe = async (recipe) => {
    const rid = recipe._id || recipe.id;
    setAdding(rid);
    const date = fmt(selectedDate);
    const uid  = user.id || user._id;
    try {
      const r = await apiFetch(`/mealPlans/Create/${date}/${uid}/${rid}`, {method:'POST', body:JSON.stringify({})});
      if (r.ok) {
        const plan = await r.json();
        setWeekMeals(prev => ({...prev, [date]: [...(prev[date]||[]), {...recipe, mealPlanId:plan._id}]}));
      }
    } catch {}
    setAdding(null);
  };

  const removeMeal = async (mealPlanId, date) => {
    try {
      const r = await apiFetch(`/mealPlans/Delete/${mealPlanId}`, {method:'DELETE'});
      if (r.ok) setWeekMeals(prev => ({...prev, [date]: (prev[date]||[]).filter(m => m.mealPlanId !== mealPlanId)}));
    } catch {}
  };

  const filtered = allRecipes.filter(r => r.recipe_name.toLowerCase().includes(searchQuery.toLowerCase()));

  const weekEnd = addDays(weekStart, 6);
  const calCells = buildMonth(calYear, calMonth);

  const weekLabel = (() => {
    const sm = MONTH_NAMES[weekStart.getMonth()].slice(0,3);
    const em = MONTH_NAMES[weekEnd.getMonth()].slice(0,3);
    return `${sm} ${weekStart.getDate()} – ${sm !== em ? em+' ':''}${weekEnd.getDate()}, ${weekEnd.getFullYear()}`;
  })();

  return (
    <div className="planner-layout">

      {/* ── Sidebar ─────────────────────────────────────── */}
      <div className="planner-sidebar">

        {/* Mini calendar */}
        <div className="mini-cal">
          <div className="mini-cal-header">
            <button className="mini-cal-nav" onClick={() => {
              const d = new Date(calYear, calMonth - 1, 1);
              setCalYear(d.getFullYear()); setCalMonth(d.getMonth());
            }}>‹</button>
            <span className="mini-cal-title">{MONTH_NAMES[calMonth]} {calYear}</span>
            <button className="mini-cal-nav" onClick={() => {
              const d = new Date(calYear, calMonth + 1, 1);
              setCalYear(d.getFullYear()); setCalMonth(d.getMonth());
            }}>›</button>
          </div>

          <div className="mini-cal-grid">
            {DAY_NAMES.map(d => <span key={d} className="mini-cal-dow">{d[0]}</span>)}
            {calCells.map((cell, i) => {
              const inMonth   = cell.getMonth() === calMonth;
              const isToday   = sameDay(cell, today);
              const isSel     = sameDay(cell, selectedDate);
              const ws        = startOfWeek(cell);
              const inSelWeek = fmt(ws) === fmt(weekStart);
              return (
                <button
                  key={i}
                  className={[
                    'mini-cal-cell',
                    !inMonth    && 'mini-cal-other',
                    isToday     && 'mini-cal-today',
                    isSel       && 'mini-cal-selected',
                    inSelWeek && !isSel && 'mini-cal-inweek',
                  ].filter(Boolean).join(' ')}
                  onClick={() => selectDay(cell)}
                >
                  {cell.getDate()}
                </button>
              );
            })}
          </div>
        </div>

        {/* Recipe browser */}
        <div className="sidebar-recipes">
          <div className="sidebar-recipes-header">
            <span className="sidebar-recipes-title">Add to <strong>{
              sameDay(selectedDate, today) ? 'Today' :
              DAY_FULL[selectedDate.getDay()]
            }</strong></span>
          </div>
          <input
            type="search"
            className="sidebar-search"
            placeholder="Search recipes…"
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
          />
          <div className="sidebar-recipe-list">
            {filtered.length === 0 && (
              <p className="sidebar-empty">No recipes found.</p>
            )}
            {filtered.map((recipe, i) => {
              const rid = recipe._id || recipe.id;
              const alreadyAdded = (weekMeals[fmt(selectedDate)]||[]).some(m => (m._id||m.id) === rid);
              return (
                <button
                  key={i}
                  className={`sidebar-recipe${alreadyAdded ? ' sidebar-recipe--added' : ''}`}
                  onClick={() => !alreadyAdded && addRecipe(recipe)}
                  disabled={alreadyAdded || adding === rid}
                >
                  <div className="sidebar-recipe-img">
                    {recipe.image_url
                      ? <img src={recipe.image_url} alt={recipe.recipe_name} />
                      : <span>{cuisineEmoji(recipe.cuisine)}</span>}
                  </div>
                  <div className="sidebar-recipe-info">
                    <span className="sidebar-recipe-name">{recipe.recipe_name}</span>
                    {recipe.cook_time > 0 && <span className="sidebar-recipe-time">{recipe.cook_time}m</span>}
                  </div>
                  <span className="sidebar-recipe-add">
                    {alreadyAdded ? '✓' : adding === rid ? '…' : '+'}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* ── Week view ────────────────────────────────────── */}
      <div className="planner-main">
        <div className="week-header-row">
          <div className="week-nav">
            <button className="week-nav-btn" onClick={() => setWeekStart(addDays(weekStart,-7))}>←</button>
            <span className="week-label">{weekLabel}</span>
            <button className="week-nav-btn" onClick={() => setWeekStart(addDays(weekStart,7))}>→</button>
          </div>
          <button className="week-today-btn" onClick={() => { selectDay(today); }}>Today</button>
        </div>

        <div className="week-view">
          {weekDays.map((day, i) => {
            const dateStr  = fmt(day);
            const meals    = weekMeals[dateStr] || [];
            const isSel    = sameDay(day, selectedDate);
            const isToday  = sameDay(day, today);
            return (
              <div
                key={i}
                className={`week-col${isSel ? ' week-col--selected' : ''}${isToday ? ' week-col--today' : ''}`}
                onClick={() => selectDay(day)}
              >
                <div className="week-col-header">
                  <span className="week-col-dow">{DAY_NAMES[day.getDay()]}</span>
                  <span className="week-col-date">{day.getDate()}</span>
                  {isToday && <span className="week-col-today-dot" />}
                </div>
                <div className="week-col-meals">
                  {meals.map((meal, j) => (
                    <div key={j} className="week-meal" onClick={e => e.stopPropagation()}>
                      <div className="week-meal-img">
                        {meal.image_url
                          ? <img src={meal.image_url} alt={meal.recipe_name} />
                          : <span>{cuisineEmoji(meal.cuisine)}</span>}
                      </div>
                      <span className="week-meal-name">{meal.recipe_name}</span>
                      <button className="week-meal-remove" onClick={() => removeMeal(meal.mealPlanId, dateStr)}>✕</button>
                    </div>
                  ))}
                  {meals.length === 0 && (
                    <div className="week-col-empty">+</div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>

    </div>
  );
}

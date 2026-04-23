import React, { useState, useEffect, useCallback } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/Calendar.css';

const DAY_NAMES   = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const DAY_FULL    = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
const MONTH_NAMES = ['January','February','March','April','May','June','July','August','September','October','November','December'];

const CUISINE_PASTELS = {
  italian:'#F5EDE8', mexican:'#E9F2E9', japanese:'#F2EDF4',
  chinese:'#F5EDEC', indian:'#F5F0E8', american:'#EBF0F5',
  french:'#EEF0F8', thai:'#F3F2E7', mediterranean:'#E8F2EF',
  greek:'#EDF0F8', korean:'#F4EDF2',
};
const cuisinePastel = c => CUISINE_PASTELS[(c||'').toLowerCase()] || '#F2F0EB';

function startOfWeek(date, weekStartDay = 0) {
  const d = new Date(date);
  const day = d.getDay();
  const diff = (day - weekStartDay + 7) % 7;
  d.setDate(d.getDate() - diff);
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
  const navigate  = useNavigate();
  const today     = new Date(); today.setHours(0,0,0,0);
  const weekStartDay = parseInt(localStorage.getItem('mise_week_start') || '0', 10);
  const [weekStart, setWeekStart] = useState(() => startOfWeek(today, weekStartDay));
  const [selectedDate, setSelectedDate] = useState(today);
  const [weekMeals, setWeekMeals]       = useState({});
  const [allRecipes, setAllRecipes]     = useState([]);
  const [searchQuery, setSearchQuery]   = useState('');
  const [adding, setAdding]             = useState(null);
  const [dragOverDate, setDragOverDate] = useState(null);
  const [calYear, setCalYear]           = useState(today.getFullYear());
  const [calMonth, setCalMonth]         = useState(today.getMonth());
  const [failedImgs, setFailedImgs]     = useState(() => new Set());

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
    const ws = startOfWeek(d, weekStartDay);
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

  const handleDragStart = (e, recipe, fromDate) => {
    e.dataTransfer.setData('recipe', JSON.stringify(recipe));
    if (fromDate) e.dataTransfer.setData('fromDate', fromDate);
    e.dataTransfer.effectAllowed = 'all';
  };

  const handleDragOver = (e, dateStr) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    setDragOverDate(dateStr);
  };

  const handleDrop = async (e, dateStr) => {
    e.preventDefault();
    setDragOverDate(null);
    try {
      const recipe = JSON.parse(e.dataTransfer.getData('recipe'));
      const fromDate = e.dataTransfer.getData('fromDate') || null;
      const uid = user.id || user._id;
      const rid = recipe._id || recipe.id;
      const alreadyAdded = (weekMeals[dateStr] || []).some(m => (m._id || m.id) === rid);

      // Moving from another day: remove from source first
      if (fromDate && fromDate !== dateStr && recipe.mealPlanId) {
        await apiFetch(`/mealPlans/Delete/${recipe.mealPlanId}`, { method: 'DELETE' });
        setWeekMeals(prev => ({ ...prev, [fromDate]: (prev[fromDate] || []).filter(m => m.mealPlanId !== recipe.mealPlanId) }));
      }

      if (!alreadyAdded || (fromDate && fromDate !== dateStr)) {
        const r = await apiFetch(`/mealPlans/Create/${dateStr}/${uid}/${rid}`, { method: 'POST', body: JSON.stringify({}) });
        if (r.ok) {
          const plan = await r.json();
          const newMeal = { ...recipe, mealPlanId: plan._id };
          setWeekMeals(prev => ({ ...prev, [dateStr]: [...(prev[dateStr] || []), newMeal] }));
        }
      }
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

  if (!user) return <Navigate to="/login" replace />;

  return (
    <div className="planner-layout">

      {/* ── Week view (full width top) ───────────────────── */}
      <div className="planner-top">
        <div className="week-header-row">
          <div className="week-nav">
            <button className="week-nav-btn" onClick={() => setWeekStart(addDays(weekStart,-7))}>←</button>
            <span className="week-label">{weekLabel}</span>
            <button className="week-nav-btn" onClick={() => setWeekStart(addDays(weekStart,7))}>→</button>
          </div>
          <button className="week-today-btn" onClick={() => selectDay(today)}>Today</button>
        </div>

        <div className="week-view">
          {weekDays.map((day, i) => {
            const dateStr = fmt(day);
            const meals   = weekMeals[dateStr] || [];
            const isSel   = sameDay(day, selectedDate);
            const isToday = sameDay(day, today);
            return (
              <div
                key={i}
                className={`week-col${isSel ? ' week-col--selected' : ''}${isToday ? ' week-col--today' : ''}${dragOverDate === dateStr ? ' week-col--dragover' : ''}`}
                onClick={() => selectDay(day)}
                onDragOver={e => handleDragOver(e, dateStr)}
                onDragLeave={() => setDragOverDate(null)}
                onDrop={e => handleDrop(e, dateStr)}
              >
                <div className="week-col-header">
                  <span className="week-col-dow">{DAY_NAMES[day.getDay()]}</span>
                  <span className="week-col-date">{day.getDate()}</span>
                  {isToday && <span className="week-col-today-dot" />}
                </div>
                <div className="week-col-meals">
                  {meals.map((meal, j) => (
                    <div
                      key={j}
                      className="week-meal"
                      draggable
                      onDragStart={e => { e.stopPropagation(); handleDragStart(e, meal, dateStr); }}
                      onClick={e => { e.stopPropagation(); navigate(`/recipes/${meal._id || meal.id}`); }}
                      style={{cursor:'pointer'}}
                    >
                      {(() => { const mid = meal._id||meal.id; const mok = meal.image_url && !failedImgs.has(mid); return (
                      <div className="week-meal-img" style={!mok ? {background: cuisinePastel(meal.cuisine)} : {}}>
                        {mok
                          ? <img src={meal.image_url} alt={meal.recipe_name} draggable={false} onError={() => setFailedImgs(p => new Set(p).add(mid))} />
                          : null}
                      </div>
                      ); })()}
                      <span className="week-meal-name">{meal.recipe_name}</span>
                      <button className="week-meal-remove" onClick={e => { e.stopPropagation(); removeMeal(meal.mealPlanId, dateStr); }}>✕</button>
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

      {/* ── Bottom: mini cal (left) + recipe picker (right) ─ */}
      <div className="planner-bottom">

        {/* Mini calendar — bottom left */}
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

        {/* Recipe picker — bottom right */}
        <div className="sidebar-recipes">
          <div className="sidebar-recipes-header">
            <span className="sidebar-recipes-title">Add to <strong>{
              sameDay(selectedDate, today) ? 'Today' : DAY_FULL[selectedDate.getDay()]
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
                  draggable={!alreadyAdded}
                  onDragStart={e => handleDragStart(e, recipe, null)}
                  onClick={() => !alreadyAdded && addRecipe(recipe)}
                  disabled={alreadyAdded || adding === rid}
                >
                  {(() => { const rok = recipe.image_url && !failedImgs.has(rid); return (
                  <div className="sidebar-recipe-img" style={!rok ? {background: cuisinePastel(recipe.cuisine)} : {}}>
                    {rok
                      ? <img src={recipe.image_url} alt={recipe.recipe_name} draggable={false} onError={() => setFailedImgs(p => new Set(p).add(rid))} />
                      : null}
                  </div>
                  ); })()}
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
    </div>
  );
}

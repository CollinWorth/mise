import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { apiFetch, imgUrl } from '../api';
import StarRating from '../components/StarRating';
import './css/Recipes.css';

const SORT_OPTIONS = [
  { value: 'default',   label: 'Newest first' },
  { value: 'top-rated', label: '★ Top rated' },
  { value: 'az',        label: 'A → Z' },
  { value: 'za',        label: 'Z → A' },
  { value: 'quickest',  label: 'Quickest' },
  { value: 'fewest',    label: 'Fewest ingredients' },
];

const CUISINE_BG = {
  italian:'#F5EDE8', mexican:'#E9F2E9', japanese:'#F2EDF4', chinese:'#F5EDEC',
  indian:'#F5F0E8', american:'#EBF0F5', french:'#EEF0F8', thai:'#F3F2E7',
  mediterranean:'#E8F2EF', greek:'#EDF0F8', korean:'#F4EDF2',
};
const cuisineBg = c => (c && CUISINE_BG[c.toLowerCase()]) || '#F2F0EB';

function totalTime(recipe) {
  const t = (recipe.prep_time || 0) + (recipe.cook_time || 0);
  return t > 0 ? `${t}m` : null;
}

const IMPORT_METHODS = [
  { icon: '🔗', label: 'From URL',    desc: 'Any recipe website',   path: '/recipes/add' },
  { icon: '🎵', label: 'From TikTok', desc: 'Paste a TikTok link',  path: '/recipes/add' },
  { icon: '📋', label: 'Paste text',  desc: 'Copy from anywhere',   path: '/recipes/add' },
  { icon: '✍️', label: 'Manually',    desc: 'Type it yourself',     path: '/recipes/add' },
];

export default function Recipes({ user }) {
  const [recipes, setRecipes]           = useState([]);
  const [search, setSearch]             = useState('');
  const [activeCuisine, setActiveCuisine] = useState('All');
  const [activeTags, setActiveTags]     = useState(new Set());
  const [loading, setLoading]           = useState(true);
  const [sort, setSort]                 = useState('default');
  const [failedImages, setFailedImages] = useState(new Set());
  const navigate  = useNavigate();
  const location  = useLocation();

  const goToRecipe = (id) => {
    sessionStorage.setItem('recipes_scrollY', String(window.scrollY));
    navigate(`/recipes/${id}`, { state: { from: location.pathname } });
  };

  useEffect(() => {
    const saved = sessionStorage.getItem('recipes_scrollY');
    if (saved) {
      sessionStorage.removeItem('recipes_scrollY');
      requestAnimationFrame(() => window.scrollTo(0, parseInt(saved, 10)));
    }
  }, []);

  useEffect(() => {
    if (!user) { setLoading(false); return; }
    setLoading(true);
    apiFetch(`/recipes/user/${user.id || user._id}`)
      .then(r => r.ok ? r.json() : [])
      .then(data => { setRecipes(data); setLoading(false); })
      .catch(() => setLoading(false));
  }, [user]);

  if (!user) {
    return (
      <div className="recipes-splash">
        <div className="recipes-splash-inner">
          <h1>Your recipes,<br />all in one place.</h1>
          <p>Save, organize, and plan your meals with mise.</p>
          <div className="recipes-splash-actions">
            <Link to="/login" className="btn-primary">Sign in</Link>
            <Link to="/register" className="btn-ghost">Create account</Link>
          </div>
        </div>
      </div>
    );
  }

  const cuisines = ['All', ...Array.from(new Set(recipes.map(r => r.cuisine).filter(Boolean)))];
  const categorySet = new Set(recipes.map(r => r.category).filter(Boolean));

  const allTags = (() => {
    const freq = {};
    recipes.forEach(r => {
      (r.tags || '').split(',').map(t => t.trim().toLowerCase()).filter(Boolean).forEach(t => {
        freq[t] = (freq[t] || 0) + 1;
      });
    });
    return Object.entries(freq).sort((a, b) => b[1] - a[1]).map(([t]) => t);
  })();

  const toggleTag = tag => setActiveTags(prev => {
    const next = new Set(prev);
    if (next.has(tag)) next.delete(tag); else next.add(tag);
    return next;
  });

  const clearFilters = () => { setActiveCuisine('All'); setActiveTags(new Set()); setSearch(''); };
  const hasFilters = activeCuisine !== 'All' || activeTags.size > 0 || search;

  const filtered = (() => {
    const q = search.toLowerCase();
    let list = recipes.filter(r => {
      const matchSearch = !q
        || r.recipe_name.toLowerCase().includes(q)
        || (r.category || '').toLowerCase().includes(q)
        || (r.cuisine  || '').toLowerCase().includes(q)
        || (r.tags     || '').toLowerCase().includes(q);
      const matchCuisine = activeCuisine === 'All' || r.cuisine === activeCuisine;
      const recipeTags = new Set((r.tags || '').split(',').map(t => t.trim().toLowerCase()).filter(Boolean));
      const matchTags = activeTags.size === 0 || [...activeTags].every(t => recipeTags.has(t));
      return matchSearch && matchCuisine && matchTags;
    });
    if (sort === 'top-rated') list = [...list].sort((a, b) => (b.avg_rating || 0) - (a.avg_rating || 0));
    else if (sort === 'az')   list = [...list].sort((a, b) => a.recipe_name.localeCompare(b.recipe_name));
    else if (sort === 'za')   list = [...list].sort((a, b) => b.recipe_name.localeCompare(a.recipe_name));
    else if (sort === 'quickest') list = [...list].sort((a, b) => {
      const ta = (a.prep_time||0)+(a.cook_time||0), tb = (b.prep_time||0)+(b.cook_time||0);
      if (!ta && !tb) return 0; if (!ta) return 1; if (!tb) return -1; return ta - tb;
    });
    else if (sort === 'fewest') list = [...list].sort((a, b) => (a.ingredients?.length||0)-(b.ingredients?.length||0));
    return list;
  })();

  const firstName = user?.name?.split(' ')[0] || 'there';
  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

  return (
    <div className="recipes-page">

      {/* ── Header ──────────────────────────────────────── */}
      <div className="recipes-header">
        <div className="recipes-header-top">
          <div>
            <p className="recipes-greeting">{greeting}, {firstName}</p>
            <h1 className="recipes-title">My Recipes</h1>
          </div>
          <button className="btn-primary recipes-add-btn" onClick={() => navigate('/recipes/add')}>
            + Add Recipe
          </button>
        </div>

        {!loading && recipes.length > 0 && (
          <div className="recipes-stats">
            <span className="recipes-stat">{recipes.length} recipe{recipes.length !== 1 ? 's' : ''}</span>
            {categorySet.size > 0 && <><span className="recipes-stat-dot">·</span><span className="recipes-stat">{categorySet.size} categor{categorySet.size !== 1 ? 'ies' : 'y'}</span></>}
            {cuisines.length > 2 && <><span className="recipes-stat-dot">·</span><span className="recipes-stat">{cuisines.length - 1} cuisine{cuisines.length > 2 ? 's' : ''}</span></>}
            {hasFilters && <><span className="recipes-stat-dot">·</span><span className="recipes-stat recipes-stat--filtered">{filtered.length} showing</span></>}
          </div>
        )}
      </div>

      {/* ── Toolbar ─────────────────────────────────────── */}
      <div className="recipes-toolbar">
        <div className="recipes-search-wrap">
          <svg className="recipes-search-icon" width="14" height="14" viewBox="0 0 16 16" fill="none">
            <circle cx="7" cy="7" r="5.5" stroke="currentColor" strokeWidth="1.5"/>
            <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
          <input
            type="search"
            className="recipes-search-input"
            placeholder="Search your recipes…"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <select className="recipes-sort-select" value={sort} onChange={e => setSort(e.target.value)}>
          {SORT_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </div>

      {/* ── Filter bar ──────────────────────────────────── */}
      {(cuisines.length > 1 || allTags.length > 0) && (
        <div className="recipes-filter-bar">
          <div className="recipes-filter-chips">
            {cuisines.slice(1).map(c => (
              <button key={c} className={`filter-chip${activeCuisine === c ? ' filter-chip--active' : ''}`} onClick={() => setActiveCuisine(activeCuisine === c ? 'All' : c)}>{c}</button>
            ))}
            {allTags.slice(0, 8).map(t => (
              <button key={t} className={`filter-chip${activeTags.has(t) ? ' filter-chip--active' : ''}`} onClick={() => toggleTag(t)}>#{t}</button>
            ))}
            {hasFilters && <button className="filter-chip filter-chip--clear" onClick={clearFilters}>✕ Clear</button>}
          </div>
        </div>
      )}

      {/* ── Content ─────────────────────────────────────── */}
      {loading ? (
        <div className="recipes-loading">
          {Array.from({ length: 8 }).map((_, i) => <div key={i} className="skeleton-card" />)}
        </div>

      ) : recipes.length === 0 ? (
        <div className="recipes-empty-start">
          <div className="recipes-empty-heading">
            <span className="recipes-empty-emoji">🍽</span>
            <h2>Your cookbook is empty</h2>
            <p>Add your first recipe to get started. Import from a website, TikTok, paste text, or type it yourself.</p>
          </div>
          <div className="recipes-import-cards">
            {IMPORT_METHODS.map(m => (
              <button key={m.label} className="recipes-import-card" onClick={() => navigate(m.path)}>
                <span className="recipes-import-icon">{m.icon}</span>
                <span className="recipes-import-label">{m.label}</span>
                <span className="recipes-import-desc">{m.desc}</span>
              </button>
            ))}
          </div>
        </div>

      ) : filtered.length === 0 ? (
        <div className="recipes-empty">
          <p className="recipes-empty-icon">🔍</p>
          <h3>No results</h3>
          <p>Try a different search or filter.</p>
          <button className="btn-ghost" onClick={clearFilters}>Clear filters</button>
        </div>

      ) : (
        <>
          <div className="recipe-grid">
            {filtered.map((recipe, idx) => {
              const rid = recipe._id || recipe.id || idx;
              const hasImage = recipe.image_url && !failedImages.has(rid);
              return (
                <div key={rid} className={`recipe-card${hasImage ? '' : ' recipe-card--text'}`}
                  onClick={() => goToRecipe(recipe._id || recipe.id)}>
                  {hasImage ? (
                    <div className="recipe-card-img">
                      <img src={imgUrl(recipe.image_url)} alt={recipe.recipe_name}
                        onError={() => setFailedImages(prev => new Set(prev).add(rid))} />
                      <div className="recipe-card-overlay">
                        <div className="recipe-card-tags">
                          {recipe.cuisine && <span className="recipe-overlay-badge">{recipe.cuisine}</span>}
                          {totalTime(recipe) && <span className="recipe-overlay-time">{totalTime(recipe)}</span>}
                        </div>
                        <div className="recipe-card-title">{recipe.recipe_name}</div>
                        {recipe.servings && <div className="recipe-card-sub">Serves {recipe.servings}</div>}
                        <div className="recipe-card-rating">
                          <StarRating rating={recipe.avg_rating || 0} showScore={recipe.avg_rating > 0} size="sm" />
                        </div>
                      </div>
                    </div>
                  ) : (
                    <div className="recipe-card-text" style={{ background: cuisineBg(recipe.cuisine) }}>
                      {recipe.category && <span className="recipe-card-text-category">{recipe.category}</span>}
                      <div className="recipe-card-title">{recipe.recipe_name}</div>
                      <div className="recipe-card-sub">
                        {[recipe.cuisine, totalTime(recipe), recipe.servings && `Serves ${recipe.servings}`]
                          .filter(Boolean).join(' · ')}
                      </div>
                      <div className="recipe-card-rating">
                        <StarRating rating={recipe.avg_rating || 0} showScore={recipe.avg_rating > 0} size="sm" />
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

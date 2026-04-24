import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { apiFetch, imgUrl } from '../api';
import './css/Recipes.css';

const SORT_OPTIONS = [
  { value: 'default',  label: 'Default' },
  { value: 'az',       label: 'A → Z' },
  { value: 'za',       label: 'Z → A' },
  { value: 'quickest', label: 'Quickest' },
  { value: 'fewest',   label: 'Fewest ingredients' },
];

const CUISINE_BG = {
  italian:       '#F5EDE8',
  mexican:       '#E9F2E9',
  japanese:      '#F2EDF4',
  chinese:       '#F5EDEC',
  indian:        '#F5F0E8',
  american:      '#EBF0F5',
  french:        '#EEF0F8',
  thai:          '#F3F2E7',
  mediterranean: '#E8F2EF',
  greek:         '#EDF0F8',
  korean:        '#F4EDF2',
};
const cuisineBg = c => (c && CUISINE_BG[c.toLowerCase()]) || '#F2F0EB';

function totalTime(recipe) {
  const t = (recipe.prep_time || 0) + (recipe.cook_time || 0);
  return t > 0 ? `${t}m` : null;
}

export default function Recipes({ user }) {
  const [recipes, setRecipes] = useState([]);
  const [search, setSearch] = useState('');
  const [activeFilter, setActiveFilter] = useState('All');
  const [loading, setLoading] = useState(true);
  const [sort, setSort] = useState('default');
  const [failedImages, setFailedImages] = useState(new Set());
  const navigate = useNavigate();
  const location = useLocation();

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

  const filtered = (() => {
    const q = search.toLowerCase();
    let list = recipes.filter(r => {
      const matchSearch = !q
        || r.recipe_name.toLowerCase().includes(q)
        || (r.category || '').toLowerCase().includes(q)
        || (r.cuisine  || '').toLowerCase().includes(q)
        || (r.tags     || '').toLowerCase().includes(q);
      const matchFilter = activeFilter === 'All' || r.cuisine === activeFilter;
      return matchSearch && matchFilter;
    });
    if (sort === 'az') list = [...list].sort((a, b) => a.recipe_name.localeCompare(b.recipe_name));
    else if (sort === 'za') list = [...list].sort((a, b) => b.recipe_name.localeCompare(a.recipe_name));
    else if (sort === 'quickest') list = [...list].sort((a, b) => {
      const ta = (a.prep_time || 0) + (a.cook_time || 0);
      const tb = (b.prep_time || 0) + (b.cook_time || 0);
      if (!ta && !tb) return 0;
      if (!ta) return 1;
      if (!tb) return -1;
      return ta - tb;
    });
    else if (sort === 'fewest') list = [...list].sort((a, b) =>
      (a.ingredients?.length || 0) - (b.ingredients?.length || 0));
    return list;
  })();

  // const [featured, ...rest] = filtered;

  return (
    <div className="recipes-page">

      {/* Toolbar */}
      <div className="recipes-toolbar">
        <div className="recipes-toolbar-left">
          <h1>Recipes</h1>
          {!loading && recipes.length > 0 && (
            <span className="recipes-count">{recipes.length}</span>
          )}
        </div>
        <div className="recipes-toolbar-right">
          <input
            type="search"
            className="recipes-search-input"
            placeholder="Search recipes..."
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
          <select
            className="recipes-sort-select"
            value={sort}
            onChange={e => setSort(e.target.value)}
            aria-label="Sort recipes"
          >
            {SORT_OPTIONS.map(o => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
          <button className="btn-primary" onClick={() => navigate('/recipes/add')}>
            + Add Recipe
          </button>
        </div>
      </div>

      {/* Filter chips — cuisine only */}
      {cuisines.length > 1 && (
        <div className="recipes-filters">
          {cuisines.map(f => (
            <button
              key={f}
              className={`filter-chip${activeFilter === f ? ' filter-chip--active' : ''}`}
              onClick={() => setActiveFilter(f)}
            >
              {f}
            </button>
          ))}
        </div>
      )}

      {/* Content */}
      {loading ? (
        <div className="recipes-loading">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="skeleton-card" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="recipes-empty">
          <p className="recipes-empty-icon">🍽</p>
          <h3>{recipes.length === 0 ? 'No recipes yet' : 'No results'}</h3>
          <p>{recipes.length === 0 ? 'Add your first recipe to get started.' : 'Try a different search or filter.'}</p>
          {recipes.length === 0 && (
            <button className="btn-primary" onClick={() => navigate('/recipes/add')}>+ Add your first recipe</button>
          )}
        </div>
      ) : (
        /* Grid */
        filtered.length > 0 && (
          <div className="recipe-grid">
            {filtered.map((recipe, idx) => {
              const rid = recipe._id || recipe.id || idx;
              const hasImage = recipe.image_url && !failedImages.has(rid);
              return (
                <div
                  key={rid}
                  className={`recipe-card${hasImage ? '' : ' recipe-card--text'}`}
                  onClick={() => goToRecipe(recipe._id || recipe.id)}
                >
                  {hasImage ? (
                    <div className="recipe-card-img">
                      <img
                        src={imgUrl(recipe.image_url)}
                        alt={recipe.recipe_name}
                        onError={() => setFailedImages(prev => new Set(prev).add(rid))}
                      />
                      <div className="recipe-card-overlay">
                        <div className="recipe-card-tags">
                          {recipe.cuisine && <span className="recipe-overlay-badge">{recipe.cuisine}</span>}
                          {recipe.tags && recipe.tags.split(',').map(t => t.trim()).filter(Boolean).slice(0, 2).map(t => (
                            <span key={t} className="recipe-overlay-badge recipe-overlay-tag">{t}</span>
                          ))}
                          {totalTime(recipe) && <span className="recipe-overlay-time">{totalTime(recipe)}</span>}
                        </div>
                        <div className="recipe-card-title">{recipe.recipe_name}</div>
                        {recipe.servings && <div className="recipe-card-sub">Serves {recipe.servings}</div>}
                      </div>
                    </div>
                  ) : (
                    <div className="recipe-card-text" style={{ background: cuisineBg(recipe.cuisine) }}>
                      <div className="recipe-card-title">{recipe.recipe_name}</div>
                      <div className="recipe-card-sub">
                        {[recipe.cuisine, totalTime(recipe), recipe.servings && `Serves ${recipe.servings}`]
                          .filter(Boolean).join(' · ')}
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )
      )}
    </div>
  );
}

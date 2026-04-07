import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/Recipes.css';

const CUISINE_GRADIENTS = {
  italian:       'linear-gradient(135deg, #8B1A1A 0%, #C0392B 100%)',
  mexican:       'linear-gradient(135deg, #1A5C2A 0%, #E67E22 100%)',
  japanese:      'linear-gradient(135deg, #6D1A4A 0%, #C0392B 100%)',
  chinese:       'linear-gradient(135deg, #8B1A1A 0%, #C0392B 100%)',
  indian:        'linear-gradient(135deg, #7D4A00 0%, #E67E22 100%)',
  american:      'linear-gradient(135deg, #1A2A5C 0%, #2C3E50 100%)',
  french:        'linear-gradient(135deg, #1A1A5C 0%, #2980B9 100%)',
  thai:          'linear-gradient(135deg, #1A5C2A 0%, #F39C12 100%)',
  mediterranean: 'linear-gradient(135deg, #1A3A5C 0%, #16A085 100%)',
  greek:         'linear-gradient(135deg, #1A2A6C 0%, #2980B9 100%)',
  default:       'linear-gradient(135deg, #2C2C2C 0%, #4A4A4A 100%)',
};

function cuisineGradient(cuisine) {
  return CUISINE_GRADIENTS[(cuisine || '').toLowerCase()] || CUISINE_GRADIENTS.default;
}

function totalTime(recipe) {
  const t = (recipe.prep_time || 0) + (recipe.cook_time || 0);
  return t > 0 ? `${t}m` : null;
}

export default function Recipes({ user }) {
  const [recipes, setRecipes] = useState([]);
  const [search, setSearch] = useState('');
  const [activeFilter, setActiveFilter] = useState('All');
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

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

  // Cuisines for filter chips
  const cuisines = ['All', ...Array.from(new Set(recipes.map(r => r.cuisine).filter(Boolean)))];

  const filtered = recipes.filter(r => {
    const matchSearch = r.recipe_name.toLowerCase().includes(search.toLowerCase());
    const matchFilter = activeFilter === 'All' || r.cuisine === activeFilter;
    return matchSearch && matchFilter;
  });

  const [featured, ...rest] = filtered;

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
          <button className="btn-primary" onClick={() => navigate('/recipes/add')}>
            + Add Recipe
          </button>
        </div>
      </div>

      {/* Filter chips */}
      {cuisines.length > 1 && (
        <div className="recipes-filters">
          {cuisines.map(c => (
            <button
              key={c}
              className={`filter-chip${activeFilter === c ? ' filter-chip--active' : ''}`}
              onClick={() => setActiveFilter(c)}
            >
              {c}
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
        <>
          {/* Featured card */}
          {featured && (
            <div
              className="recipe-featured"
              onClick={() => navigate(`/recipes/${featured._id || featured.id}`)}
            >
              <div className="recipe-featured-img">
                {featured.image_url
                  ? <img src={featured.image_url} alt={featured.recipe_name} />
                  : <div className="recipe-placeholder" style={{ background: cuisineGradient(featured.cuisine) }} />
                }
              </div>
              <div className="recipe-featured-overlay">
                <div className="recipe-featured-tags">
                  {featured.cuisine && <span className="recipe-overlay-badge">{featured.cuisine}</span>}
                  {totalTime(featured) && <span className="recipe-overlay-time">{totalTime(featured)}</span>}
                </div>
                <h2 className="recipe-featured-title">{featured.recipe_name}</h2>
                {featured.servings && (
                  <p className="recipe-featured-sub">Serves {featured.servings}</p>
                )}
              </div>
            </div>
          )}

          {/* Grid */}
          {rest.length > 0 && (
            <div className="recipe-grid">
              {rest.map((recipe, idx) => (
                <div
                  key={recipe._id || recipe.id || idx}
                  className="recipe-card"
                  onClick={() => navigate(`/recipes/${recipe._id || recipe.id}`)}
                >
                  <div className="recipe-card-img">
                    {recipe.image_url
                      ? <img src={recipe.image_url} alt={recipe.recipe_name} />
                      : <div className="recipe-placeholder" style={{ background: cuisineGradient(recipe.cuisine) }} />
                    }
                    <div className="recipe-card-overlay">
                      <div className="recipe-card-tags">
                        {recipe.cuisine && <span className="recipe-overlay-badge">{recipe.cuisine}</span>}
                        {totalTime(recipe) && <span className="recipe-overlay-time">{totalTime(recipe)}</span>}
                      </div>
                      <div className="recipe-card-title">{recipe.recipe_name}</div>
                      {recipe.servings && <div className="recipe-card-sub">Serves {recipe.servings}</div>}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

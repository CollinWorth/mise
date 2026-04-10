import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/Recipes.css';
import './css/ProfilePage.css';

const CUISINE_GRADIENTS = {
  italian:'linear-gradient(135deg,#8B1A1A 0%,#C0392B 100%)',
  mexican:'linear-gradient(135deg,#1A5C2A 0%,#E67E22 100%)',
  japanese:'linear-gradient(135deg,#6D1A4A 0%,#C0392B 100%)',
  chinese:'linear-gradient(135deg,#8B1A1A 0%,#C0392B 100%)',
  indian:'linear-gradient(135deg,#7D4A00 0%,#E67E22 100%)',
  american:'linear-gradient(135deg,#1A2A5C 0%,#2C3E50 100%)',
  french:'linear-gradient(135deg,#1A1A5C 0%,#2980B9 100%)',
  thai:'linear-gradient(135deg,#1A5C2A 0%,#F39C12 100%)',
  mediterranean:'linear-gradient(135deg,#1A3A5C 0%,#16A085 100%)',
  greek:'linear-gradient(135deg,#1A2A6C 0%,#2980B9 100%)',
  default:'linear-gradient(135deg,#2C2C2C 0%,#4A4A4A 100%)',
};
const cuisineGradient = c => CUISINE_GRADIENTS[(c||'').toLowerCase()] || CUISINE_GRADIENTS.default;
const totalTime = r => { const t = (r.prep_time||0)+(r.cook_time||0); return t > 0 ? `${t}m` : null; };

export default function ProfilePage({ user, onLogout }) {
  const [recipes, setRecipes] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) return;
    const uid = user.id || user._id;
    apiFetch(`/recipes/user/${uid}`)
      .then(r => r.ok ? r.json() : [])
      .then(data => { setRecipes(data); setLoading(false); })
      .catch(() => setLoading(false));
  }, [user]);

  if (!user) {
    navigate('/login');
    return null;
  }

  const initial = user.name?.[0]?.toUpperCase() ?? '?';
  const publicCount = recipes.filter(r => r.is_public).length;

  return (
    <div className="pf-page page">

      {/* ── Profile header ── */}
      <div className="pf-header">
        <div className="pf-avatar">{initial}</div>
        <div className="pf-info">
          <h1 className="pf-name">{user.name}</h1>
          <p className="pf-email">{user.email}</p>
          <div className="pf-stats">
            <div className="pf-stat">
              <span className="pf-stat-num">{recipes.length}</span>
              <span className="pf-stat-label">recipes</span>
            </div>
            <div className="pf-stat">
              <span className="pf-stat-num">{publicCount}</span>
              <span className="pf-stat-label">public</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Recipe grid ── */}
      <div className="pf-section-title">Your Recipes</div>

      {loading ? (
        <div className="recipes-loading">
          {Array.from({length:4}).map((_,i) => <div key={i} className="skeleton-card" />)}
        </div>
      ) : recipes.length === 0 ? (
        <div className="recipes-empty">
          <p className="recipes-empty-icon">🍽</p>
          <h3>No recipes yet</h3>
          <p>Add your first recipe to get started.</p>
          <button className="btn-primary" onClick={() => navigate('/recipes/add')}>+ Add Recipe</button>
        </div>
      ) : (
        <div className="recipe-grid">
          {recipes.map((recipe, idx) => (
            <div
              key={recipe._id||recipe.id||idx}
              className="recipe-card"
              onClick={() => navigate(`/recipes/${recipe._id||recipe.id}`)}
            >
              <div className="recipe-card-img">
                {recipe.image_url
                  ? <img src={recipe.image_url} alt={recipe.recipe_name} />
                  : <div className="recipe-placeholder" style={{background:cuisineGradient(recipe.cuisine)}} />
                }
                <div className="recipe-card-overlay">
                  <div className="recipe-card-tags">
                    {recipe.cuisine && <span className="recipe-overlay-badge">{recipe.cuisine}</span>}
                    {recipe.is_public && <span className="recipe-overlay-badge pf-public-badge">public</span>}
                    {totalTime(recipe) && <span className="recipe-overlay-time">{totalTime(recipe)}</span>}
                  </div>
                  <div className="recipe-card-title">{recipe.recipe_name}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

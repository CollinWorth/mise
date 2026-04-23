import React, { useState, useEffect } from 'react';
import { useNavigate, Navigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/Recipes.css';
import './css/ProfilePage.css';

const CUISINE_PASTELS = {
  italian:'#F5EDE8', mexican:'#E9F2E9', japanese:'#F2EDF4',
  chinese:'#F5EDEC', indian:'#F5F0E8', american:'#EBF0F5',
  french:'#EEF0F8', thai:'#F3F2E7', mediterranean:'#E8F2EF',
  greek:'#EDF0F8', korean:'#F4EDF2',
};
const cuisinePastel = c => CUISINE_PASTELS[(c||'').toLowerCase()] || '#F2F0EB';
const totalTime = r => { const t = (r.prep_time||0)+(r.cook_time||0); return t > 0 ? `${t}m` : null; };

export default function ProfilePage({ user, onLogout }) {
  const [recipes, setRecipes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [followerCount, setFollowerCount]   = useState(0);
  const [followingCount, setFollowingCount] = useState(0);
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) return;
    const uid = user.id || user._id;
    Promise.all([
      apiFetch(`/recipes/user/${uid}`).then(r => r.ok ? r.json() : []),
      apiFetch(`/users/${uid}`).then(r => r.ok ? r.json() : {}),
    ]).then(([data, profile]) => {
      setRecipes(data);
      setFollowerCount(profile.follower_count ?? 0);
      setFollowingCount(profile.following_count ?? 0);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [user]);

  if (!user) return <Navigate to="/login" replace />;

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
            <div className="pf-stat">
              <span className="pf-stat-num">{followerCount}</span>
              <span className="pf-stat-label">followers</span>
            </div>
            <div className="pf-stat">
              <span className="pf-stat-num">{followingCount}</span>
              <span className="pf-stat-label">following</span>
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
                  : <div className="recipe-placeholder" style={{background:cuisinePastel(recipe.cuisine)}} />
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

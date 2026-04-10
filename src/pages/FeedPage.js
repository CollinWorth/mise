import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/FeedPage.css';

const CUISINE_GRADIENTS = {
  italian:'linear-gradient(135deg,#8B1A1A,#C0392B)',
  mexican:'linear-gradient(135deg,#1A5C2A,#E67E22)',
  japanese:'linear-gradient(135deg,#6D1A4A,#C0392B)',
  chinese:'linear-gradient(135deg,#8B1A1A,#C0392B)',
  indian:'linear-gradient(135deg,#7D4A00,#E67E22)',
  american:'linear-gradient(135deg,#1A2A5C,#2C3E50)',
  french:'linear-gradient(135deg,#1A1A5C,#2980B9)',
  thai:'linear-gradient(135deg,#1A5C2A,#F39C12)',
  mediterranean:'linear-gradient(135deg,#1A3A5C,#16A085)',
  greek:'linear-gradient(135deg,#1A2A6C,#2980B9)',
  default:'linear-gradient(135deg,#2C2C2C,#4A4A4A)',
};
const cuisineGradient = c => CUISINE_GRADIENTS[(c||'').toLowerCase()] || CUISINE_GRADIENTS.default;

function timeAgo(dateStr) {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr);
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d}d`;
  return new Date(dateStr).toLocaleDateString();
}

export default function FeedPage({ user }) {
  const [recipes, setRecipes]     = useState([]);
  const [loading, setLoading]     = useState(true);
  const [likedIds, setLikedIds]   = useState(() => {
    try { return new Set(JSON.parse(localStorage.getItem('mise_liked') || '[]')); }
    catch { return new Set(); }
  });
  const [likeCounts, setLikeCounts] = useState({});
  const [savedIds, setSavedIds]     = useState(new Set());
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) { setLoading(false); return; }
    apiFetch('/recipes/feed')
      .then(r => r.ok ? r.json() : [])
      .then(data => {
        setRecipes(data);
        const counts = {};
        data.forEach(r => { counts[r._id || r.id] = r.like_count || 0; });
        setLikeCounts(counts);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, [user]);

  const handleLike = useCallback(async (e, recipeId) => {
    e.stopPropagation();
    const isLiked = likedIds.has(recipeId);
    const delta = isLiked ? -1 : 1;
    setLikeCounts(prev => ({ ...prev, [recipeId]: Math.max(0, (prev[recipeId] || 0) + delta) }));
    const next = new Set(likedIds);
    isLiked ? next.delete(recipeId) : next.add(recipeId);
    setLikedIds(next);
    localStorage.setItem('mise_liked', JSON.stringify([...next]));
    const ep = isLiked ? `/recipes/${recipeId}/unlike` : `/recipes/${recipeId}/like`;
    try { await apiFetch(ep, { method: 'POST', body: '{}' }); } catch {}
  }, [likedIds]);

  const handleSave = useCallback(async (e, recipeId) => {
    e.stopPropagation();
    if (savedIds.has(recipeId)) return;
    setSavedIds(prev => new Set([...prev, recipeId]));
    try { await apiFetch(`/recipes/${recipeId}/save`, { method: 'POST', body: '{}' }); } catch {}
  }, [savedIds]);

  if (!user) {
    return (
      <div className="feed-page">
        <div className="feed-empty">
          <span className="feed-empty-icon">📰</span>
          <h3>Sign in to see your feed</h3>
          <p>Follow cooks to see their latest recipes here.</p>
          <Link to="/login" className="btn-primary">Sign in</Link>
        </div>
      </div>
    );
  }

  return (
    <div className="feed-page">
      <div className="feed-inner">
        <h1 className="feed-title">Feed</h1>

        {loading ? (
          <div className="feed-skeletons">
            {[0,1,2].map(i => <div key={i} className="feed-skeleton" />)}
          </div>
        ) : recipes.length === 0 ? (
          <div className="feed-empty">
            <span className="feed-empty-icon">👨‍🍳</span>
            <h3>Nothing in your feed yet</h3>
            <p>Follow some cooks on the Explore page to see their recipes here.</p>
            <button className="btn-primary" onClick={() => navigate('/explore')}>Go to Explore</button>
          </div>
        ) : (
          <div className="feed-posts">
            {recipes.map(recipe => {
              const id = recipe._id || recipe.id;
              const liked = likedIds.has(id);
              const saved = savedIds.has(id);
              const likeCount = likeCounts[id] ?? 0;
              const authorInitial = recipe.author_name?.[0]?.toUpperCase() ?? '?';
              const totalTime = (recipe.prep_time || 0) + (recipe.cook_time || 0);

              return (
                <article key={id} className="feed-post">
                  {/* Author header */}
                  <div className="feed-post-author">
                    <Link to={`/users/${recipe.user_id}`} className="feed-author-link" onClick={e => e.stopPropagation()}>
                      <div className="feed-author-avatar">{authorInitial}</div>
                      <span className="feed-author-name">{recipe.author_name || 'Chef'}</span>
                    </Link>
                    {recipe.category && <span className="feed-post-category">{recipe.category}</span>}
                  </div>

                  {/* Image */}
                  <div className="feed-post-img" onClick={() => navigate(`/recipes/${id}`)}>
                    {recipe.image_url
                      ? <img src={recipe.image_url} alt={recipe.recipe_name} loading="lazy" />
                      : <div className="feed-post-placeholder" style={{background: cuisineGradient(recipe.cuisine)}}>
                          <span className="feed-post-placeholder-name">{recipe.recipe_name}</span>
                        </div>
                    }
                  </div>

                  {/* Action row */}
                  <div className="feed-post-actions">
                    <button
                      className={`feed-action-btn feed-like-btn${liked ? ' feed-like-btn--liked' : ''}`}
                      onClick={e => handleLike(e, id)}
                    >
                      <svg width="22" height="22" viewBox="0 0 16 16" fill={liked ? 'currentColor' : 'none'}>
                        <path d="M8 13.5C8 13.5 1.5 9.5 1.5 5.5C1.5 3.567 3.067 2 5 2C6.126 2 7.12 2.557 7.758 3.41L8 3.73L8.242 3.41C8.88 2.557 9.874 2 11 2C12.933 2 14.5 3.567 14.5 5.5C14.5 9.5 8 13.5 8 13.5Z"
                          stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
                      </svg>
                    </button>
                    <button className="feed-action-btn" onClick={() => navigate(`/recipes/${id}`)}>
                      <svg width="22" height="22" viewBox="0 0 16 16" fill="none">
                        <path d="M14 10C14 10.5523 13.5523 11 13 11H4.5L2 13.5V3C2 2.44772 2.44772 2 3 2H13C13.5523 2 14 2.44772 14 3V10Z"
                          stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
                      </svg>
                    </button>
                    <button
                      className={`feed-action-btn feed-save-btn${saved ? ' feed-save-btn--saved' : ''}`}
                      onClick={e => handleSave(e, id)}
                      style={{marginLeft:'auto'}}
                    >
                      <svg width="20" height="22" viewBox="0 0 14 18" fill={saved ? 'currentColor' : 'none'}>
                        <path d="M1 1H13V17L7 13L1 17V1Z"
                          stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
                      </svg>
                    </button>
                  </div>

                  {/* Meta */}
                  <div className="feed-post-meta">
                    {likeCount > 0 && (
                      <span className="feed-like-count">{likeCount} {likeCount === 1 ? 'like' : 'likes'}</span>
                    )}
                    <div className="feed-post-info" onClick={() => navigate(`/recipes/${id}`)}>
                      <span className="feed-post-title">{recipe.recipe_name}</span>
                      <span className="feed-post-details">
                        {recipe.cuisine && <>{recipe.cuisine}</>}
                        {recipe.cuisine && totalTime > 0 && <span className="feed-dot">·</span>}
                        {totalTime > 0 && <>{totalTime}m</>}
                      </span>
                    </div>
                    {recipe.tags && (
                      <p className="feed-post-tags">
                        {recipe.tags.split(',').map(t => t.trim()).filter(Boolean).map(t => (
                          <span key={t} className="feed-tag">#{t}</span>
                        ))}
                      </p>
                    )}
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

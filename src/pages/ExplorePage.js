import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/ExplorePage.css';
// Note: uses own card styles — intentionally different from Recipes page

const CUISINE_EMOJI = {
  italian:'🍝', mexican:'🌮', japanese:'🍱', chinese:'🥡',
  indian:'🍛', american:'🍔', french:'🥐', thai:'🍜',
  mediterranean:'🫒', greek:'🫙',
};
const cuisineEmoji = c => (c && CUISINE_EMOJI[c.toLowerCase()]) || '🍽';

const STATIC_TABS = [
  { id: 'all',      label: 'All' },
  { id: 'trending', label: '🔥 Trending' },
  { id: 'new',      label: '✨ New' },
  { id: 'quick',    label: '⚡ Quick' },
];

function totalMinutes(r) { return (r.prep_time || 0) + (r.cook_time || 0); }
function fmtTime(r) { const t = totalMinutes(r); return t > 0 ? `${t}m` : null; }

export default function ExplorePage({ user }) {
  const [recipes, setRecipes]       = useState([]);
  const [loading, setLoading]       = useState(true);
  const [search, setSearch]         = useState('');
  const [activeTab, setActiveTab]   = useState('all');
  const [likedIds, setLikedIds]     = useState(() => {
    try { return new Set(JSON.parse(localStorage.getItem('mise_liked') || '[]')); }
    catch { return new Set(); }
  });
  const [likeCounts, setLikeCounts] = useState({});
  const [savedIds, setSavedIds]     = useState(new Set());
  const [savingId, setSavingId]     = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    apiFetch('/recipes/explore')
      .then(r => r.ok ? r.json() : [])
      .then(data => {
        setRecipes(data);
        const counts = {};
        data.forEach(r => { counts[r._id || r.id] = r.like_count || 0; });
        setLikeCounts(counts);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  // Persist liked IDs to localStorage
  const persistLiked = useCallback((set) => {
    localStorage.setItem('mise_liked', JSON.stringify([...set]));
  }, []);

  const handleLike = async (e, recipeId) => {
    e.stopPropagation();
    const isLiked = likedIds.has(recipeId);
    const endpoint = isLiked ? `/recipes/${recipeId}/unlike` : `/recipes/${recipeId}/like`;

    // Optimistic update
    const delta = isLiked ? -1 : 1;
    setLikeCounts(prev => ({ ...prev, [recipeId]: Math.max(0, (prev[recipeId] || 0) + delta) }));
    const next = new Set(likedIds);
    isLiked ? next.delete(recipeId) : next.add(recipeId);
    setLikedIds(next);
    persistLiked(next);

    try { await apiFetch(endpoint, { method: 'POST', body: JSON.stringify({}) }); }
    catch { /* revert on failure */ setLikeCounts(prev => ({ ...prev, [recipeId]: Math.max(0, (prev[recipeId] || 0) - delta) })); }
  };

  const handleSave = async (e, recipeId) => {
    e.stopPropagation();
    if (!user) { navigate('/login'); return; }
    if (savedIds.has(recipeId)) return;
    setSavingId(recipeId);
    try {
      const r = await apiFetch(`/recipes/${recipeId}/save`, { method: 'POST', body: JSON.stringify({}) });
      if (r.ok) setSavedIds(prev => new Set([...prev, recipeId]));
    } catch {}
    setSavingId(null);
  };

  // Build dynamic tabs from cuisines + categories
  const cuisineSet  = new Set(recipes.map(r => r.cuisine).filter(Boolean));
  const categorySet = new Set(recipes.map(r => r.category).filter(Boolean));
  const dynamicTabs = [
    ...Array.from(categorySet).map(c => ({ id: c, label: c })),
    ...Array.from(cuisineSet).filter(c => !categorySet.has(c)).map(c => ({ id: c, label: c })),
  ];
  const allTabs = [...STATIC_TABS, ...dynamicTabs];

  // Apply tab filter
  let filtered = [...recipes];
  if (activeTab === 'trending') {
    filtered.sort((a, b) => (b.like_count || 0) - (a.like_count || 0));
  } else if (activeTab === 'quick') {
    filtered = filtered.filter(r => { const t = totalMinutes(r); return t > 0 && t <= 30; });
  } else if (activeTab !== 'all' && activeTab !== 'new') {
    filtered = filtered.filter(r => {
      const tags = r.tags ? r.tags.split(',').map(t => t.trim().toLowerCase()) : [];
      return r.cuisine === activeTab
        || r.category === activeTab
        || tags.includes(activeTab.toLowerCase());
    });
  }

  // Apply search (name + category + cuisine + tags + ingredients hint)
  if (search.trim()) {
    const q = search.toLowerCase();
    filtered = filtered.filter(r =>
      r.recipe_name.toLowerCase().includes(q) ||
      (r.category || '').toLowerCase().includes(q) ||
      (r.cuisine  || '').toLowerCase().includes(q) ||
      (r.tags     || '').toLowerCase().includes(q)
    );
  }

  return (
    <div className="ex-page">

      {/* ── Header ─────────────────────────────────────── */}
      <div className="ex-header">
        <div className="ex-header-top">
          <h1 className="ex-title">Explore</h1>
          <div className="ex-search-wrap">
            <svg className="ex-search-icon" width="14" height="14" viewBox="0 0 16 16" fill="none">
              <circle cx="7" cy="7" r="5.5" stroke="currentColor" strokeWidth="1.5"/>
              <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
            </svg>
            <input
              className="ex-search"
              type="search"
              placeholder="Search recipes…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
        </div>

        {/* Category tabs */}
        <div className="ex-tabs">
          {allTabs.map(tab => (
            <button
              key={tab.id}
              className={`ex-tab${activeTab === tab.id ? ' ex-tab--active' : ''}`}
              onClick={() => setActiveTab(tab.id)}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Content ────────────────────────────────────── */}
      {loading ? (
        <div className="ex-grid">
          {Array.from({length: 8}).map((_, i) => (
            <div key={i} className="ex-skeleton" />
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <div className="ex-empty">
          <span className="ex-empty-icon">🌍</span>
          <h3>{recipes.length === 0 ? 'Nothing shared yet' : 'No results'}</h3>
          <p>{recipes.length === 0
            ? "Open a recipe you own, toggle \"Share publicly\", and it'll appear here."
            : 'Try a different search or category.'
          }</p>
        </div>
      ) : (
        <div className="ex-grid">
          {filtered.map(recipe => {
            const id = recipe._id || recipe.id;
            const liked = likedIds.has(id);
            const saved = savedIds.has(id);
            const count = likeCounts[id] ?? 0;
            const time = fmtTime(recipe);

            return (
              <article
                key={id}
                className="ex-card"
                onClick={() => navigate(`/recipes/${id}`)}
              >
                {/* Image */}
                <div className="ex-card-img">
                  {recipe.image_url
                    ? <img src={recipe.image_url} alt={recipe.recipe_name} loading="lazy" />
                    : <div className="ex-card-emoji">{cuisineEmoji(recipe.cuisine)}</div>
                  }
                  {recipe.cuisine && (
                    <span className="ex-card-cuisine">{recipe.cuisine}</span>
                  )}
                </div>

                {/* Body */}
                <div className="ex-card-body">
                  <h3 className="ex-card-title">{recipe.recipe_name}</h3>
                  <div className="ex-card-meta">
                    {recipe.category && <span className="ex-card-tag ex-card-category">{recipe.category}</span>}
                    {time && <><span className="ex-card-dot">·</span><span>{time}</span></>}
                    {recipe.servings && <><span className="ex-card-dot">·</span><span>Serves {recipe.servings}</span></>}
                    {recipe.tags && recipe.tags.split(',').map(t => t.trim()).filter(Boolean).slice(0,1).map(t => (
                      <span key={t} className="ex-card-tag">{t}</span>
                    ))}
                  </div>
                </div>

                {/* Footer */}
                <div className="ex-card-footer" onClick={e => e.stopPropagation()}>
                  {recipe.author_name && (
                    <a
                      href={`/users/${recipe.user_id}`}
                      className="ex-card-author"
                      onClick={e => { e.stopPropagation(); e.preventDefault(); window.location.href = `/users/${recipe.user_id}`; }}
                    >
                      <span className="ex-card-author-avatar">{recipe.author_name[0].toUpperCase()}</span>
                      <span className="ex-card-author-name">{recipe.author_name}</span>
                    </a>
                  )}
                  <button
                    className={`ex-like-btn${liked ? ' ex-like-btn--liked' : ''}`}
                    onClick={e => handleLike(e, id)}
                    aria-label={liked ? 'Unlike' : 'Like'}
                  >
                    <svg width="15" height="15" viewBox="0 0 16 16" fill={liked ? 'currentColor' : 'none'}>
                      <path d="M8 13.5C8 13.5 1.5 9.5 1.5 5.5C1.5 3.567 3.067 2 5 2C6.126 2 7.12 2.557 7.758 3.41L8 3.73L8.242 3.41C8.88 2.557 9.874 2 11 2C12.933 2 14.5 3.567 14.5 5.5C14.5 9.5 8 13.5 8 13.5Z"
                        stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"/>
                    </svg>
                    <span>{count > 0 ? count : ''}</span>
                  </button>

                  <button
                    className={`ex-save-btn${saved ? ' ex-save-btn--saved' : ''}`}
                    onClick={e => handleSave(e, id)}
                    disabled={savingId === id}
                  >
                    {savingId === id ? '…' : saved ? '✓ Saved' : '+ Save'}
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      )}
    </div>
  );
}

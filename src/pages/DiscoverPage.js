import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { apiFetch } from '../api';
import StarRating from '../components/StarRating';
import './css/ExplorePage.css';
import './css/FeedPage.css';

const CUISINE_BG = {
  italian:'#F5EDE8', mexican:'#E9F2E9', japanese:'#F2EDF4', chinese:'#F5EDEC',
  indian:'#F5F0E8', american:'#EBF0F5', french:'#EEF0F8', thai:'#F3F2E7',
  mediterranean:'#E8F2EF', greek:'#EDF0F8', korean:'#F4EDF2',
};
const cuisineBg = c => (c && CUISINE_BG[c.toLowerCase()]) || '#F2F0EB';

const STATIC_TABS = [
  { id: 'all',      label: 'All' },
  { id: 'trending', label: '🔥 Trending' },
  { id: 'new',      label: '✨ New' },
  { id: 'quick',    label: '⚡ Quick' },
];

function totalMinutes(r) { return (r.prep_time || 0) + (r.cook_time || 0); }
function fmtTime(r) { const t = totalMinutes(r); return t > 0 ? `${t}m` : null; }

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

export default function DiscoverPage({ user }) {
  const [tab, setTab] = useState('all'); // 'following' | explore filter tabs

  // Shared save state
  const [savedIds, setSavedIds] = useState(new Set());
  const [savingId, setSavingId] = useState(null);

  // Explore state
  const [exploreRecipes, setExploreRecipes] = useState([]);
  const [exploreLoading, setExploreLoading] = useState(true);
  const [failedImages, setFailedImages]     = useState(new Set());
  const [search, setSearch]                 = useState('');
  const [activeFilter, setActiveFilter]     = useState('all');

  // Feed state
  const [feedRecipes, setFeedRecipes]   = useState([]);
  const [feedLoading, setFeedLoading]   = useState(false);
  const [feedLoaded, setFeedLoaded]     = useState(false);

  // People state
  const [peopleSearch, setPeopleSearch] = useState('');
  const [people, setPeople]             = useState([]);
  const [peopleLoading, setPeopleLoading] = useState(false);
  const [followedIds, setFollowedIds]   = useState(new Set());
  const peopleTimer = useRef(null);

  const navigate = useNavigate();
  const location = useLocation();

  const goToRecipe = (id) => {
    sessionStorage.setItem('discover_scrollY', String(window.scrollY));
    navigate(`/recipes/${id}`, { state: { from: location.pathname } });
  };

  // Restore scroll when returning from a recipe
  useEffect(() => {
    const saved = sessionStorage.getItem('discover_scrollY');
    if (saved) {
      sessionStorage.removeItem('discover_scrollY');
      requestAnimationFrame(() => window.scrollTo(0, parseInt(saved, 10)));
    }
  }, []);

  // Load explore recipes on mount
  useEffect(() => {
    apiFetch('/recipes/explore')
      .then(r => r.ok ? r.json() : [])
      .then(data => {
        setExploreRecipes(data);
        setExploreLoading(false);
      })
      .catch(() => setExploreLoading(false));
  }, []);

  // Debounced people search
  useEffect(() => {
    if (tab !== 'people') return;
    clearTimeout(peopleTimer.current);
    if (!peopleSearch.trim()) { setPeople([]); return; }
    setPeopleLoading(true);
    peopleTimer.current = setTimeout(() => {
      apiFetch(`/users/search?q=${encodeURIComponent(peopleSearch.trim())}`)
        .then(r => r.ok ? r.json() : [])
        .then(data => { setPeople(data); setPeopleLoading(false); })
        .catch(() => setPeopleLoading(false));
    }, 300);
    return () => clearTimeout(peopleTimer.current);
  }, [peopleSearch, tab]);

  const handleFollow = async (e, targetId) => {
    e.stopPropagation();
    if (!user) { navigate('/login'); return; }
    const alreadyFollowing = followedIds.has(targetId);
    setFollowedIds(prev => {
      const next = new Set(prev);
      alreadyFollowing ? next.delete(targetId) : next.add(targetId);
      return next;
    });
    try {
      await apiFetch(`/follows/${targetId}`, { method: alreadyFollowing ? 'DELETE' : 'POST', body: '{}' });
    } catch {
      setFollowedIds(prev => {
        const next = new Set(prev);
        alreadyFollowing ? next.add(targetId) : next.delete(targetId);
        return next;
      });
    }
  };

  // Load feed when switching to 'following' tab
  useEffect(() => {
    if (tab !== 'following' || !user || feedLoaded) return;
    setFeedLoading(true);
    apiFetch('/recipes/feed')
      .then(r => r.ok ? r.json() : [])
      .then(data => {
        setFeedRecipes(data);
        setFeedLoading(false);
        setFeedLoaded(true);
      })
      .catch(() => setFeedLoading(false));
  }, [tab, user, feedLoaded]);

  const handleSave = async (e, recipeId) => {
    e.stopPropagation();
    if (!user) { navigate('/login'); return; }
    if (savedIds.has(recipeId)) return;
    setSavingId(recipeId);
    try {
      const r = await apiFetch(`/recipes/${recipeId}/save`, { method: 'POST', body: '{}' });
      if (r.ok) setSavedIds(prev => new Set([...prev, recipeId]));
    } catch {}
    setSavingId(null);
  };

  // Build explore filter tabs
  const cuisineSet  = new Set(exploreRecipes.map(r => r.cuisine).filter(Boolean));
  const categorySet = new Set(exploreRecipes.map(r => r.category).filter(Boolean));
  const dynamicTabs = [
    ...Array.from(categorySet).map(c => ({ id: c, label: c })),
    ...Array.from(cuisineSet).filter(c => !categorySet.has(c)).map(c => ({ id: c, label: c })),
  ];
  const filterTabs = [...STATIC_TABS, ...dynamicTabs];

  // Apply explore filter + search
  let filtered = [...exploreRecipes];
  if (activeFilter === 'trending') {
    filtered.sort((a, b) => (b.avg_rating || 0) - (a.avg_rating || 0));
  } else if (activeFilter === 'quick') {
    filtered = filtered.filter(r => { const t = totalMinutes(r); return t > 0 && t <= 30; });
  } else if (activeFilter !== 'all' && activeFilter !== 'new') {
    filtered = filtered.filter(r => {
      const tags = r.tags ? r.tags.split(',').map(t => t.trim().toLowerCase()) : [];
      return r.cuisine === activeFilter || r.category === activeFilter || tags.includes(activeFilter.toLowerCase());
    });
  }
  if (search.trim()) {
    const q = search.toLowerCase();
    filtered = filtered.filter(r =>
      r.recipe_name.toLowerCase().includes(q) ||
      (r.category || '').toLowerCase().includes(q) ||
      (r.cuisine  || '').toLowerCase().includes(q) ||
      (r.tags     || '').toLowerCase().includes(q)
    );
  }

  const showingFeed = tab === 'following';

  return (
    <div className="ex-page">

      {/* ── Header ─────────────────────────────────────── */}
      <div className="ex-header">
        <div className="ex-header-top">
          {/* Mode toggle */}
          <div className="discover-mode-toggle">
            {user && (
              <button
                className={`discover-mode-btn${showingFeed ? ' discover-mode-btn--active' : ''}`}
                onClick={() => setTab('following')}
              >
                Following
              </button>
            )}
            <button
              className={`discover-mode-btn${!showingFeed && tab !== 'people' ? ' discover-mode-btn--active' : ''}`}
              onClick={() => { setTab('all'); setActiveFilter('all'); }}
            >
              Discover
            </button>
            <button
              className={`discover-mode-btn${tab === 'people' ? ' discover-mode-btn--active' : ''}`}
              onClick={() => setTab('people')}
            >
              People
            </button>
          </div>

          {/* Search — recipes (explore) or people */}
          {(!showingFeed && tab !== 'people') && (
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
          )}
          {tab === 'people' && (
            <div className="ex-search-wrap">
              <svg className="ex-search-icon" width="14" height="14" viewBox="0 0 16 16" fill="none">
                <circle cx="7" cy="7" r="5.5" stroke="currentColor" strokeWidth="1.5"/>
                <path d="M11 11l3 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
              </svg>
              <input
                className="ex-search"
                type="search"
                placeholder="Search people…"
                value={peopleSearch}
                onChange={e => setPeopleSearch(e.target.value)}
                autoFocus
              />
            </div>
          )}
        </div>

        {/* Filter tabs (explore only) */}
        {!showingFeed && tab !== 'people' && (
          <div className="ex-tabs">
            {filterTabs.map(t => (
              <button
                key={t.id}
                className={`ex-tab${activeFilter === t.id ? ' ex-tab--active' : ''}`}
                onClick={() => setActiveFilter(t.id)}
              >
                {t.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* ── Following (Feed) ───────────────────────────── */}
      {showingFeed && (
        <div className="feed-inner">
          {feedLoading ? (
            <div className="feed-skeletons">
              {[0,1,2].map(i => <div key={i} className="feed-skeleton" />)}
            </div>
          ) : feedRecipes.length === 0 ? (
            <div className="feed-empty">
              <span className="feed-empty-icon">👨‍🍳</span>
              <h3>Nothing in your feed yet</h3>
              <p>Follow some cooks on Discover to see their recipes here.</p>
              <button className="btn-primary" onClick={() => setTab('all')}>Go to Discover</button>
            </div>
          ) : (
            <div className="feed-posts">
              {feedRecipes.map(recipe => {
                const id = recipe._id || recipe.id;
                const saved = savedIds.has(id);
                const authorInitial = recipe.author_name?.[0]?.toUpperCase() ?? '?';
                const totalTime = (recipe.prep_time || 0) + (recipe.cook_time || 0);
                return (
                  <article key={id} className="feed-post">
                    <div className="feed-post-author">
                      <Link to={`/users/${recipe.user_id}`} className="feed-author-link" onClick={e => e.stopPropagation()}>
                        <div className="feed-author-avatar">{authorInitial}</div>
                        <span className="feed-author-name">{recipe.author_name || 'Chef'}</span>
                      </Link>
                      {recipe.category && <span className="feed-post-category">{recipe.category}</span>}
                    </div>
                    <div className="feed-post-img" onClick={() => goToRecipe(id)}>
                      {recipe.image_url
                        ? <img src={recipe.image_url} alt={recipe.recipe_name} loading="lazy" />
                        : <div className="feed-post-placeholder" style={{background: cuisineBg(recipe.cuisine)}}>
                            {recipe.category && <span className="feed-placeholder-pill">{recipe.category}</span>}
                            <span className="feed-post-placeholder-name">{recipe.recipe_name}</span>
                            {totalTime > 0 && <span className="feed-placeholder-time">{totalTime} min</span>}
                          </div>
                      }
                    </div>
                    <div className="feed-post-actions">
                      <div className="feed-action-btn feed-star-display">
                        <StarRating rating={recipe.avg_rating || 0} showCount count={recipe.rating_count || 0} size="sm" />
                      </div>
                      <button className="feed-action-btn" onClick={() => goToRecipe(id)}>
                        <svg width="22" height="22" viewBox="0 0 16 16" fill="none">
                          <path d="M14 10C14 10.5523 13.5523 11 13 11H4.5L2 13.5V3C2 2.44772 2.44772 2 3 2H13C13.5523 2 14 2.44772 14 3V10Z"
                            stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
                        </svg>
                        {(recipe.comment_count || 0) > 0 && <span className="feed-action-count">{recipe.comment_count}</span>}
                      </button>
                      <button className={`feed-action-btn feed-save-btn${saved ? ' feed-save-btn--saved' : ''}`} onClick={e => handleSave(e, id)} style={{marginLeft:'auto'}}>
                        <svg width="20" height="22" viewBox="0 0 14 18" fill={saved ? 'currentColor' : 'none'}>
                          <path d="M1 1H13V17L7 13L1 17V1Z" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
                        </svg>
                      </button>
                    </div>
                    <div className="feed-post-meta">
                      <div className="feed-post-info" onClick={() => goToRecipe(id)}>
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
      )}

      {/* ── People ─────────────────────────────────────── */}
      {tab === 'people' && (
        <div className="people-section">
          {!peopleSearch.trim() ? (
            <div className="ex-empty">
              <span className="ex-empty-icon">👤</span>
              <h3>Find cooks</h3>
              <p>Search by name to find and follow other cooks.</p>
            </div>
          ) : peopleLoading ? (
            <div className="people-list">
              {[0,1,2].map(i => <div key={i} className="people-skeleton" />)}
            </div>
          ) : people.length === 0 ? (
            <div className="ex-empty">
              <span className="ex-empty-icon">🔍</span>
              <h3>No results</h3>
              <p>No one found for "{peopleSearch}". Try a different name.</p>
            </div>
          ) : (
            <div className="people-list">
              {people.map(person => {
                const pid = person._id || person.id;
                const isMe = user && (user.id === pid || user._id === pid);
                const following = followedIds.has(pid);
                return (
                  <div key={pid} className="people-card" onClick={() => navigate(`/users/${pid}`)}>
                    <div className="people-card-avatar">{person.name?.[0]?.toUpperCase() ?? '?'}</div>
                    <div className="people-card-info">
                      <span className="people-card-name">{person.name}</span>
                      {person.recipe_count > 0 && (
                        <span className="people-card-meta">{person.recipe_count} recipe{person.recipe_count !== 1 ? 's' : ''}</span>
                      )}
                    </div>
                    {!isMe && user && (
                      <button
                        className={`people-follow-btn${following ? ' people-follow-btn--following' : ''}`}
                        onClick={e => handleFollow(e, pid)}
                      >
                        {following ? 'Following' : 'Follow'}
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* ── Discover (Explore grid) ─────────────────────── */}
      {!showingFeed && tab !== 'people' && (
        exploreLoading ? (
          <div className="ex-grid">
            {Array.from({length: 8}).map((_, i) => <div key={i} className="ex-skeleton" />)}
          </div>
        ) : filtered.length === 0 ? (
          <div className="ex-empty">
            <span className="ex-empty-icon">🌍</span>
            <h3>{exploreRecipes.length === 0 ? 'Nothing shared yet' : 'No results'}</h3>
            <p>{exploreRecipes.length === 0
              ? "Open a recipe you own, toggle \"Share publicly\", and it'll appear here."
              : 'Try a different search or category.'
            }</p>
          </div>
        ) : (
          <div className="ex-grid">
            {filtered.map(recipe => {
              const id = recipe._id || recipe.id;
              const saved = savedIds.has(id);
              const time = fmtTime(recipe);
              const hasImage = recipe.image_url && !failedImages.has(id);
              return (
                <article
                  key={id}
                  className={`ex-card${hasImage ? '' : ' ex-card--no-image'}`}
                  style={hasImage ? {} : { background: cuisineBg(recipe.cuisine) }}
                  onClick={() => goToRecipe(id)}
                >
                  {hasImage && (
                    <div className="ex-card-img">
                      <img src={recipe.image_url} alt={recipe.recipe_name} loading="lazy"
                        onError={() => setFailedImages(prev => new Set(prev).add(id))} />
                      {recipe.cuisine && <span className="ex-card-cuisine">{recipe.cuisine}</span>}
                    </div>
                  )}
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
                    {recipe.is_modified && recipe.original_author_name && (
                      <div className="ex-card-remix">↪ modified from {recipe.original_author_name}</div>
                    )}
                  </div>
                  <div className="ex-card-footer" onClick={e => e.stopPropagation()}>
                    {recipe.author_name && (
                      <a href={`/users/${recipe.user_id}`} className="ex-card-author"
                        onClick={e => { e.stopPropagation(); e.preventDefault(); navigate(`/users/${recipe.user_id}`); }}>
                        <span className="ex-card-author-avatar">{recipe.author_name[0].toUpperCase()}</span>
                        <span className="ex-card-author-name">{recipe.author_name}</span>
                      </a>
                    )}
                    <StarRating rating={recipe.avg_rating || 0} showCount count={recipe.rating_count || 0} size="sm" />
                    <button className={`ex-save-btn${saved ? ' ex-save-btn--saved' : ''}`} onClick={e => handleSave(e, id)} disabled={savingId === id}>
                      {savingId === id ? '…' : saved ? '✓ Saved' : '+ Save'}
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        )
      )}
    </div>
  );
}

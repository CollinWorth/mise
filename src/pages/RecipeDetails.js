import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import { useToast } from '../contexts/ToastContext';
import './css/RecipeDetails.css';

const CUISINE_PASTELS = {
  italian:'#F5EDE8', mexican:'#E9F2E9', japanese:'#F2EDF4',
  chinese:'#F5EDEC', indian:'#F5F0E8', american:'#EBF0F5',
  french:'#EEF0F8', thai:'#F3F2E7', mediterranean:'#E8F2EF',
  greek:'#EDF0F8', korean:'#F4EDF2',
};
const cuisinePastel = c => CUISINE_PASTELS[(c||'').toLowerCase()] || '#F2F0EB';

function timeAgo(dateStr) {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr);
  const m = Math.floor(diff / 60000);
  if (m < 1) return 'just now';
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return d < 7 ? `${d}d ago` : new Date(dateStr).toLocaleDateString();
}

export default function RecipeDetails({ user }) {
  const { id } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const [recipe, setRecipe]     = useState(null);
  const [loading, setLoading]   = useState(true);
  const [servings, setServings] = useState(null);
  const [checked, setChecked]   = useState({});
  const [comments, setComments] = useState([]);
  const [commentText, setCommentText] = useState('');
  const [submittingComment, setSubmittingComment] = useState(false);
  const [versions, setVersions] = useState([]);
  const [showVersions, setShowVersions] = useState(false);
  const [imgError, setImgError] = useState(false);
  const [liked, setLiked] = useState(false);
  const [likeCount, setLikeCount] = useState(0);

  useEffect(() => { window.scrollTo(0, 0); }, [id]);

  useEffect(() => {
    Promise.all([
      apiFetch(`/recipes/${id}`).then(r => r.ok ? r.json() : null),
      apiFetch(`/comments/${id}`).then(r => r.ok ? r.json() : []),
    ]).then(([data, cmts]) => {
      setRecipe(data);
      if (data?.servings) setServings(data.servings);
      setComments(cmts || []);
      setLikeCount(data?.like_count || 0);
      setLoading(false);
      if (data?.is_public) {
        apiFetch(`/recipes/${id}/versions`).then(r => r.ok ? r.json() : []).then(setVersions).catch(() => {});
        try {
          const stored = JSON.parse(localStorage.getItem('mise_liked') || '[]');
          setLiked(stored.includes(id));
        } catch {}
      }
    }).catch(() => setLoading(false));
  }, [id]);

  const submitComment = async (e) => {
    e.preventDefault();
    if (!commentText.trim() || submittingComment) return;
    setSubmittingComment(true);
    try {
      const r = await apiFetch(`/comments/${id}`, { method: 'POST', body: JSON.stringify({ text: commentText.trim() }) });
      if (r.ok) {
        const newComment = await r.json();
        setComments(prev => [...prev, newComment]);
        setCommentText('');
      }
    } catch {}
    setSubmittingComment(false);
  };

  const deleteComment = async (commentId) => {
    try {
      const r = await apiFetch(`/comments/${commentId}`, { method: 'DELETE' });
      if (r.ok) setComments(prev => prev.filter(c => c._id !== commentId));
    } catch {}
  };

  const handleLike = async () => {
    if (liked) return;
    setLiked(true);
    setLikeCount(c => c + 1);
    try {
      const stored = JSON.parse(localStorage.getItem('mise_liked') || '[]');
      if (!stored.includes(id)) { stored.push(id); localStorage.setItem('mise_liked', JSON.stringify(stored)); }
      await apiFetch(`/recipes/${id}/like`, { method: 'POST', body: '{}' });
    } catch {
      setLiked(false);
      setLikeCount(c => Math.max(0, c - 1));
    }
  };

  const handleDelete = async () => {
    if (!window.confirm('Delete this recipe?')) return;
    const res = await apiFetch(`/recipes/${id}`, { method: 'DELETE' });
    if (res.ok) navigate('/recipes');
    else alert('Failed to delete recipe');
  };

  const toggleIng = (idx) => setChecked(c => ({ ...c, [idx]: !c[idx] }));

  if (loading) return (
    <div className="page rd-page">
      <div className="rd-skeleton-hero" />
      <div className="rd-skeleton-title" />
    </div>
  );
  if (!recipe) return <div className="page"><p>Recipe not found.</p></div>;

  const steps = recipe.instructions
    ? recipe.instructions.split('\n').map(s => s.replace(/^\d+[.)]\s*/, '').trim()).filter(Boolean)
    : [];

  const totalTime = (recipe.prep_time || 0) + (recipe.cook_time || 0);
  const isOwner = user && (user.id === recipe.user_id || user._id === recipe.user_id);
  const isPublic = recipe.is_public;

  const baseServings = recipe.servings || 1;
  const scaleFactor  = servings ? servings / baseServings : 1;

  function scaleQty(qty) {
    if (!qty || scaleFactor === 1) return qty;
    // Try to parse number from string like "1.5", "1/2", "2"
    const frac = qty.match(/^(\d+)\s*\/\s*(\d+)$/);
    if (frac) {
      const n = (parseInt(frac[1]) / parseInt(frac[2])) * scaleFactor;
      return fmtNum(n);
    }
    const n = parseFloat(qty);
    if (isNaN(n)) return qty;
    return fmtNum(n * scaleFactor);
  }

  function fmtNum(n) {
    if (n === Math.round(n)) return String(Math.round(n));
    const rounded = Math.round(n * 4) / 4; // nearest quarter
    const whole = Math.floor(rounded);
    const frac = rounded - whole;
    const fracStr = frac === 0.25 ? '¼' : frac === 0.5 ? '½' : frac === 0.75 ? '¾' : '';
    if (whole === 0) return fracStr || n.toFixed(1);
    return fracStr ? `${whole} ${fracStr}` : String(whole);
  }

  return (
    <div className="rd-page">
      {/* ── Hero ─────────────────────────────────────────── */}
      {(() => {
        const hasImg = recipe.image_url && !imgError;
        return (
        <div className={`rd-hero${hasImg ? '' : ' rd-hero--noimage'}`}>
          {hasImg ? (
            <>
              <img src={recipe.image_url} alt="" className="rd-hero-blur" aria-hidden="true" onError={() => setImgError(true)} />
              <img src={recipe.image_url} alt={recipe.recipe_name} className="rd-hero-img" onError={() => setImgError(true)} />
            </>
          ) : (
            <div className="rd-hero-placeholder" style={{ background: cuisinePastel(recipe.cuisine) }} />
          )}
          {hasImg && <div className="rd-hero-overlay" />}
          <div className="rd-hero-content">
            <button className="rd-back" onClick={() => navigate('/recipes')}>← Recipes</button>
            <h1 className="rd-title">{recipe.recipe_name}</h1>
          <div className="rd-meta-row">
              {recipe.prep_time > 0 && <span className="rd-meta-pill">Prep {recipe.prep_time}m</span>}
              {recipe.cook_time > 0 && <span className="rd-meta-pill">Cook {recipe.cook_time}m</span>}
              {totalTime > 0        && <span className="rd-meta-pill rd-meta-total">Total {totalTime}m</span>}
              {recipe.servings      && <span className="rd-meta-pill">Serves {recipe.servings}</span>}
              {recipe.category      && <span className="rd-meta-pill rd-meta-category">{recipe.category}</span>}
              {recipe.cuisine       && <span className="rd-meta-pill rd-meta-accent">{recipe.cuisine}</span>}
            </div>
          </div>
        </div>
        );
      })()}

      <div className="rd-body page">
        {/* ── Tags ─────────────────────────────────────────── */}
        {recipe.tags && (
          <div className="rd-tags">
            {recipe.tags.split(',').map(t => t.trim()).filter(Boolean).map(tag => (
              <span key={tag} className="badge">{tag}</span>
            ))}
          </div>
        )}

        {/* ── Provenance ───────────────────────────────────── */}
        {recipe.is_modified && recipe.original_author_name && (
          <div className="rd-provenance">
            <span className="rd-provenance-icon">↪</span>
            <span>Modified from original by <strong>{recipe.original_author_name}</strong></span>
          </div>
        )}

        {/* ── Versions ─────────────────────────────────────── */}
        {versions.length > 0 && (
          <div className="rd-versions">
            <button className="rd-versions-toggle" onClick={() => setShowVersions(v => !v)}>
              {showVersions ? '▾' : '▸'} {versions.length} remix{versions.length !== 1 ? 'es' : ''} of this recipe
            </button>
            {showVersions && (
              <ul className="rd-versions-list">
                {versions.map(v => (
                  <li key={v._id} className="rd-version-item" onClick={() => navigate(`/recipes/${v._id}`)}>
                    <span className="rd-version-name">{v.recipe_name}</span>
                    <span className="rd-version-by">by {v.author_name}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}

<div className="rd-content">
          {/* ── Ingredients ──────────────────────────────── */}
          <div className="rd-panel">
            <div className="rd-panel-header">
              <h2 className="rd-panel-title">Ingredients</h2>
              {recipe.servings && (
                <div className="rd-servings">
                  <button className="rd-servings-btn" onClick={() => setServings(s => Math.max(1, (s ?? baseServings) - 1))}>−</button>
                  <span className="rd-servings-label">{servings ?? baseServings} serving{(servings ?? baseServings) !== 1 ? 's' : ''}</span>
                  <button className="rd-servings-btn" onClick={() => setServings(s => (s ?? baseServings) + 1)}>+</button>
                </div>
              )}
            </div>
            <ul className="rd-ing-list">
              {recipe.ingredients.map((ing, idx) => (
                <li
                  key={idx}
                  className={`rd-ing-item${checked[idx] ? ' rd-ing-checked' : ''}`}
                  onClick={() => toggleIng(idx)}
                >
                  <span className="rd-ing-check">{checked[idx] ? '✓' : ''}</span>
                  <span className="rd-ing-text">
                    {[scaleQty(ing.quantity), ing.unit, ing.name].filter(Boolean).join(' ')}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          {/* ── Instructions ─────────────────────────────── */}
          {steps.length > 0 && (
            <div className="rd-panel rd-panel-steps">
              <h2 className="rd-panel-title">Instructions</h2>
              <ol className="rd-steps">
                {steps.map((step, idx) => (
                  <li key={idx} className="rd-step">
                    <span className="rd-step-num">{idx + 1}</span>
                    <p className="rd-step-text">{step}</p>
                  </li>
                ))}
              </ol>
            </div>
          )}
        </div>

        {/* ── Actions ──────────────────────────────────────── */}
        <div className="rd-actions">
          {steps.length > 0 && (
            <button className="btn-primary" onClick={() => navigate(`/recipes/${id}/cook`)}>
              Start Cooking
            </button>
          )}
          {isPublic && (
            <button
              className={`rd-like-btn${liked ? ' rd-like-btn--liked' : ''}`}
              onClick={handleLike}
              title={liked ? 'Liked' : 'Like this recipe'}
            >
              <svg width="16" height="16" viewBox="0 0 16 16" fill={liked ? 'currentColor' : 'none'}>
                <path d="M8 13.5C8 13.5 1.5 9.5 1.5 5.5C1.5 3.567 3.067 2 5 2C6.126 2 7.12 2.557 7.758 3.41L8 3.73L8.242 3.41C8.88 2.557 9.874 2 11 2C12.933 2 14.5 3.567 14.5 5.5C14.5 9.5 8 13.5 8 13.5Z"
                  stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round"/>
              </svg>
              {likeCount > 0 && <span>{likeCount}</span>}
            </button>
          )}
          <button
            className="btn-ghost"
            onClick={() => {
              navigator.clipboard.writeText(window.location.href);
              toast.info('Link copied to clipboard');
            }}
          >
            Share
          </button>
          {isOwner && (
            <>
              <button className="btn-ghost" onClick={() => navigate(`/recipes/${id}/edit`)}>Edit recipe</button>
              <button className="btn-danger" onClick={handleDelete}>Delete</button>
            </>
          )}
        </div>

        {/* ── Comments ─────────────────────────────────────── */}
        <div className="rd-comments">
          <h2 className="rd-comments-title">
            Comments {comments.length > 0 && <span className="rd-comments-count">{comments.length}</span>}
          </h2>

          {user && (
            <form className="rd-comment-form" onSubmit={submitComment}>
              <div className="rd-comment-avatar">{user.name?.[0]?.toUpperCase() ?? '?'}</div>
              <input
                className="rd-comment-input"
                placeholder="Add a comment…"
                value={commentText}
                onChange={e => setCommentText(e.target.value)}
              />
              <button type="submit" className="rd-comment-submit" disabled={!commentText.trim() || submittingComment}>
                {submittingComment ? '…' : 'Post'}
              </button>
            </form>
          )}

          {comments.length === 0 ? (
            <p className="rd-comments-empty">No comments yet. {!user && 'Sign in to be the first.'}</p>
          ) : (
            <div className="rd-comment-list">
              {comments.map(c => (
                <div key={c._id} className="rd-comment">
                  <div className="rd-comment-avatar rd-comment-avatar--sm">
                    {c.user_name?.[0]?.toUpperCase() ?? '?'}
                  </div>
                  <div className="rd-comment-body">
                    <div className="rd-comment-header">
                      <span className="rd-comment-author">{c.user_name}</span>
                      <span className="rd-comment-time">{timeAgo(c.created_at)}</span>
                    </div>
                    <p className="rd-comment-text">{c.text}</p>
                  </div>
                  {user && (user.id === c.user_id || user._id === c.user_id) && (
                    <button className="rd-comment-delete" onClick={() => deleteComment(c._id)}>✕</button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

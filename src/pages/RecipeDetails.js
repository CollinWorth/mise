import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/RecipeDetails.css';

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

function cuisineGradient(c) {
  return CUISINE_GRADIENTS[(c || '').toLowerCase()] || CUISINE_GRADIENTS.default;
}

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
  const [recipe, setRecipe]     = useState(null);
  const [loading, setLoading]   = useState(true);
  const [checked, setChecked]   = useState({});
  const [comments, setComments] = useState([]);
  const [commentText, setCommentText] = useState('');
  const [submittingComment, setSubmittingComment] = useState(false);

  useEffect(() => {
    Promise.all([
      apiFetch(`/recipes/${id}`).then(r => r.ok ? r.json() : null),
      apiFetch(`/comments/${id}`).then(r => r.ok ? r.json() : []),
    ]).then(([data, cmts]) => {
      setRecipe(data);
      setComments(cmts || []);
      setLoading(false);
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

  return (
    <div className="rd-page">
      {/* ── Hero ─────────────────────────────────────────── */}
      <div className="rd-hero">
        {recipe.image_url ? (
          <>
            <img src={recipe.image_url} alt="" className="rd-hero-blur" aria-hidden="true" />
            <img src={recipe.image_url} alt={recipe.recipe_name} className="rd-hero-img" />
          </>
        ) : (
          <div className="rd-hero-placeholder" style={{ background: cuisineGradient(recipe.cuisine) }} />
        )}
        <div className="rd-hero-overlay" />
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

      <div className="rd-body page">
        {/* ── Tags ─────────────────────────────────────────── */}
        {recipe.tags && (
          <div className="rd-tags">
            {recipe.tags.split(',').map(t => t.trim()).filter(Boolean).map(tag => (
              <span key={tag} className="badge">{tag}</span>
            ))}
          </div>
        )}

        {/* ── Cook mode button ─────────────────────────────── */}
        {steps.length > 0 && (
          <button className="rd-cook-btn" onClick={() => navigate(`/recipes/${id}/cook`)}>
            <span>🍳</span> Start Cook Mode
          </button>
        )}

        <div className="rd-content">
          {/* ── Ingredients ──────────────────────────────── */}
          <div className="rd-panel">
            <h2 className="rd-panel-title">Ingredients</h2>
            <ul className="rd-ing-list">
              {recipe.ingredients.map((ing, idx) => (
                <li
                  key={idx}
                  className={`rd-ing-item${checked[idx] ? ' rd-ing-checked' : ''}`}
                  onClick={() => toggleIng(idx)}
                >
                  <span className="rd-ing-check">{checked[idx] ? '✓' : ''}</span>
                  <span className="rd-ing-text">
                    {[ing.quantity, ing.unit, ing.name].filter(Boolean).join(' ')}
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
          <button className="btn-ghost" onClick={() => navigate(`/recipes/${id}/edit`)}>Edit recipe</button>
          <button className="btn-danger" onClick={handleDelete}>Delete</button>
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

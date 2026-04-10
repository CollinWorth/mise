import React, { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/CookMode.css';

export default function CookMode() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [recipe, setRecipe]     = useState(null);
  const [loading, setLoading]   = useState(true);
  const [stepIdx, setStepIdx]   = useState(0);
  const [checked, setChecked]   = useState({});
  const [ingOpen, setIngOpen]   = useState(false);

  useEffect(() => {
    apiFetch(`/recipes/${id}`)
      .then(r => r.ok ? r.json() : null)
      .then(data => { setRecipe(data); setLoading(false); })
      .catch(() => setLoading(false));
  }, [id]);

  const steps = recipe?.instructions
    ? recipe.instructions.split('\n').map(s => s.replace(/^\d+[.)]\s*/, '').trim()).filter(Boolean)
    : [];

  const prev = useCallback(() => setStepIdx(i => Math.max(0, i - 1)), []);
  const next = useCallback(() => setStepIdx(i => Math.min(steps.length - 1, i + 1)), [steps.length]);

  useEffect(() => {
    const handler = (e) => {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') next();
      if (e.key === 'ArrowLeft'  || e.key === 'ArrowUp')   prev();
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [next, prev]);

  if (loading) return <div className="cm-page cm-loading"><div className="cm-spinner-lg" /></div>;
  if (!recipe || steps.length === 0) return (
    <div className="cm-page cm-empty">
      <p>No steps found.</p>
      <button className="btn-ghost" onClick={() => navigate(`/recipes/${id}`)}>← Back</button>
    </div>
  );

  const progress = ((stepIdx + 1) / steps.length) * 100;
  const done = stepIdx === steps.length - 1;

  return (
    <div className="cm-page">
      {/* ── Header ── */}
      <div className="cm-header">
        <button className="cm-exit" onClick={() => navigate(`/recipes/${id}`)}>✕ Exit</button>
        <span className="cm-recipe-name">{recipe.recipe_name}</span>
        <span className="cm-step-counter">{stepIdx + 1} / {steps.length}</span>
      </div>

      {/* ── Progress bar ── */}
      <div className="cm-progress-track">
        <div className="cm-progress-fill" style={{ width: `${progress}%` }} />
      </div>

      {/* ── Step ── */}
      <div className="cm-body">
        <div className="cm-step-card">
          <div className="cm-step-badge">Step {stepIdx + 1}</div>
          <p className="cm-step-text">{steps[stepIdx]}</p>
        </div>

        {/* ── Navigation ── */}
        <div className="cm-nav">
          <button className="cm-nav-btn cm-nav-prev" onClick={prev} disabled={stepIdx === 0}>
            ← Prev
          </button>
          {done ? (
            <button className="cm-nav-btn cm-nav-done" onClick={() => navigate(`/recipes/${id}`)}>
              🎉 Done!
            </button>
          ) : (
            <button className="cm-nav-btn cm-nav-next" onClick={next}>
              Next →
            </button>
          )}
        </div>

        {/* ── Step dots ── */}
        <div className="cm-dots">
          {steps.map((_, i) => (
            <button
              key={i}
              className={`cm-dot${i === stepIdx ? ' cm-dot-active' : ''}${i < stepIdx ? ' cm-dot-done' : ''}`}
              onClick={() => setStepIdx(i)}
            />
          ))}
        </div>

        {/* ── Ingredients drawer ── */}
        <div className={`cm-ing-drawer${ingOpen ? ' cm-ing-open' : ''}`}>
          <button className="cm-ing-toggle" onClick={() => setIngOpen(o => !o)}>
            {ingOpen ? '▾ Hide ingredients' : '▸ Show ingredients'}
            <span className="cm-ing-count">{recipe.ingredients.length}</span>
          </button>
          {ingOpen && (
            <ul className="cm-ing-list">
              {recipe.ingredients.map((ing, idx) => (
                <li
                  key={idx}
                  className={`cm-ing-item${checked[idx] ? ' cm-ing-checked' : ''}`}
                  onClick={() => setChecked(c => ({ ...c, [idx]: !c[idx] }))}
                >
                  <span className="cm-ing-check">{checked[idx] ? '✓' : ''}</span>
                  <span>{[ing.quantity, ing.unit, ing.name].filter(Boolean).join(' ')}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}

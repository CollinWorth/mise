import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import ComboBox from '../components/ComboBox';
import './css/AddRecipePage.css';

const BASE_CATEGORIES = [
  'Soup','Stew','Chili','Salad','Bowl','Pasta','Rice','Curry','Stir-fry',
  'Tacos','Burger','Pizza','Sandwich','Wrap','Roast','Grilled','Seafood',
  'Breakfast','Brunch','Eggs','Pancakes','Oatmeal','Smoothie',
  'Snack','Appetizer','Side dish','Dip','Bread','Cake','Cookies',
  'Muffins','Pie','Dessert','Drink',
];

const BASE_TAGS = [
  'quick','easy','healthy','vegetarian','vegan','gluten-free',
  'dairy-free','spicy','meal prep','high-protein','low-carb',
  'keto','comfort food','weeknight','kid-friendly','budget-friendly',
];

function mergeUnique(...arrays) {
  const seen = new Set();
  return arrays.flat().filter(v => {
    const k = v.toLowerCase();
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

const METHODS = [
  { id: 'url',    icon: '🔗', label: 'Import from URL',    sub: 'Paste a link from any recipe website or blog' },
  { id: 'tiktok', icon: '🎵', label: 'Import from TikTok', sub: "Share a TikTok link — we'll pull the recipe from the description" },
  { id: 'paste',  icon: '📋', label: 'Paste text',          sub: "Paste a recipe from anywhere and we'll parse it" },
  { id: 'manual', icon: '✍️', label: 'Enter manually',      sub: 'Type in the recipe yourself' },
];

function emptyForm(user) {
  return {
    recipe_name: '', prep_time: '', cook_time: '', servings: '',
    cuisine: '', category: '', tags: '', image_url: '', is_public: true,
    user_id: user?.id || user?._id || '',
  };
}

export default function AddRecipe({ user }) {
  const navigate = useNavigate();
  const [method, setMethod]           = useState(null);
  const [form, setForm]               = useState(() => emptyForm(user));
  const [ingredients, setIngredients] = useState([{ name: '', quantity: '', unit: '', is_section: false }]);
  const dragIdx = useRef(null);
  const [dragOver, setDragOver] = useState(null);
  const [steps, setSteps]             = useState(['']);
  const [importing, setImporting]     = useState(false);
  const [imported, setImported]       = useState(false);
  const [importUrl, setImportUrl]     = useState('');
  const [pasteText, setPasteText]     = useState('');
  const [importError, setImportError] = useState('');
  const [submitting, setSubmitting]   = useState(false);
  const [categorySuggestions, setCategorySuggestions] = useState(BASE_CATEGORIES);
  const [tagSuggestions, setTagSuggestions]           = useState(BASE_TAGS);
  const [uploading, setUploading] = useState(false);
  const fileRef = useRef(null);

  useEffect(() => {
    if (user && (user.id || user._id))
      setForm(f => ({ ...f, user_id: user.id || user._id }));
  }, [user]);

  useEffect(() => {
    if (!user) return;
    apiFetch(`/recipes/user/${user.id || user._id}`)
      .then(r => r.ok ? r.json() : [])
      .then(recipes => {
        const cats = recipes.map(r => r.category).filter(Boolean);
        const tags = recipes.flatMap(r => r.tags ? r.tags.split(',').map(t => t.trim()).filter(Boolean) : []);
        setCategorySuggestions(mergeUnique(cats, BASE_CATEGORIES));
        setTagSuggestions(mergeUnique(tags, BASE_TAGS));
      }).catch(() => {});
  }, [user]); // eslint-disable-line

  const fillForm = (data) => {
    setForm(f => ({
      ...f,
      recipe_name: data.recipe_name || f.recipe_name,
      cuisine:     data.cuisine     || f.cuisine,
      category:    data.category    || f.category,
      image_url:   data.image_url   || f.image_url,
      prep_time:   data.prep_time != null ? String(data.prep_time) : f.prep_time,
      cook_time:   data.cook_time != null ? String(data.cook_time) : f.cook_time,
      servings:    data.servings    || f.servings,
      tags:        data.tags        || f.tags,
    }));
    if (data.ingredients?.length) setIngredients(data.ingredients);
    if (data.instructions) {
      const lines = data.instructions.split('\n')
        .map(s => s.replace(/^\d+[.)]\s*/, '').trim())
        .filter(Boolean);
      setSteps(lines.length ? lines : ['']);
    }
    setImported(true);
    setMethod('manual');
  };

  const handleImport = async () => {
    const url = importUrl.trim();
    if (!url) return;
    setImporting(true); setImportError('');
    try {
      const r = await apiFetch('/recipes/scrape-smart', { method: 'POST', body: JSON.stringify({ url }) });
      const data = await r.json();
      if (!r.ok) { setImportError(data.detail || 'Failed to import'); setImporting(false); return; }
      fillForm(data);
    } catch { setImportError('Could not reach server'); }
    setImporting(false);
  };

  const handleParseText = async () => {
    if (!pasteText.trim()) return;
    setImporting(true); setImportError('');
    try {
      const r = await apiFetch('/recipes/parse-text', { method: 'POST', body: JSON.stringify({ text: pasteText.trim() }) });
      const data = await r.json();
      if (!r.ok) { setImportError(data.detail || 'Could not parse'); setImporting(false); return; }
      fillForm(data);
    } catch { setImportError('Could not reach server'); }
    setImporting(false);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    const recipe = {
      ...form,
      instructions: steps.filter(Boolean).join('\n'),
      ingredients: ingredients.filter(i => i.name).map(({ name, quantity, unit, is_section }) => ({ name, quantity, unit, is_section: is_section || false })),
      prep_time: form.prep_time ? Number(form.prep_time) : undefined,
      cook_time: form.cook_time ? Number(form.cook_time) : undefined,
      servings:  form.servings  ? Number(form.servings)  : undefined,
    };
    try {
      const res = await apiFetch('/recipes/', { method: 'POST', body: JSON.stringify(recipe) });
      if (res.ok) {
        const data = await res.json();
        navigate(data.id ? `/recipes/${data.id}` : '/recipes');
      } else alert('Failed to save recipe');
    } catch (err) { alert('Error: ' + err.message); }
    setSubmitting(false);
  };

  const updateIng  = (idx, field, val) => setIngredients(ingredients.map((x, i) => i === idx ? { ...x, [field]: val } : x));
  const updateStep = (idx, val)        => setSteps(steps.map((s, i) => i === idx ? val : s));

  const handleStepDragStart = (idx) => { dragIdx.current = idx; };
  const handleStepDragOver  = (e, idx) => { e.preventDefault(); setDragOver(idx); };
  const handleStepDrop      = (idx) => {
    if (dragIdx.current === null || dragIdx.current === idx) { dragIdx.current = null; setDragOver(null); return; }
    const next = [...steps];
    const [moved] = next.splice(dragIdx.current, 1);
    next.splice(idx, 0, moved);
    setSteps(next);
    dragIdx.current = null;
    setDragOver(null);
  };

  const handleImageUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploading(true);
    const fd = new FormData();
    fd.append('file', file);
    const token = localStorage.getItem('mise_token');
    try {
      const res = await fetch(`${process.env.REACT_APP_API_URL || 'http://localhost:8000'}/recipes/upload-image`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: fd,
      });
      if (res.ok) {
        const { url } = await res.json();
        setForm(f => ({ ...f, image_url: url }));
      }
    } catch {}
    setUploading(false);
    e.target.value = '';
  };

  const goBack = () => { setMethod(null); setImported(false); setImportError(''); };

  // ── Method picker ────────────────────────────────────────────
  if (!method) {
    return (
      <div className="page ar-page">
        <button className="ar-back" onClick={() => navigate('/recipes')}>← Recipes</button>
        <h1 className="ar-heading">How would you like to<br />add a recipe?</h1>
        <div className="ar-methods">
          {METHODS.map(m => (
            <button key={m.id} className="ar-method-card" onClick={() => setMethod(m.id)}>
              <span className="ar-method-icon">{m.icon}</span>
              <div className="ar-method-text">
                <div className="ar-method-label">{m.label}</div>
                <div className="ar-method-sub">{m.sub}</div>
              </div>
              <span className="ar-chevron">›</span>
            </button>
          ))}
        </div>
      </div>
    );
  }

  const showImportPanel = (method === 'url' || method === 'tiktok' || method === 'paste') && !imported;

  return (
    <div className="page ar-page">
      {showImportPanel ? (
        <button className="ar-back" onClick={goBack}>← Back</button>
      ) : (
        <div className="page-header">
          <h1>Add Recipe</h1>
          <button className="ar-back" onClick={goBack}>← Back</button>
        </div>
      )}

      {/* ── Import panels ──────────────────────────────────── */}
      {showImportPanel && (
        <div className="ar-import-panel">
          {(method === 'url' || method === 'tiktok') && (
            <>
              <h2 className="ar-import-title">
                {method === 'tiktok' ? 'Paste your TikTok link' : 'Paste a recipe URL'}
              </h2>
              {method === 'tiktok' && (
                <p className="ar-import-hint">In TikTok → tap Share → Copy link, then paste it here.</p>
              )}
              <div className="ar-import-row">
                <input
                  type="url"
                  placeholder={method === 'tiktok' ? 'https://www.tiktok.com/…' : 'https://…'}
                  value={importUrl}
                  onChange={e => { setImportUrl(e.target.value); setImportError(''); }}
                  onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), handleImport())}
                  autoFocus
                />
                <button className="btn-primary" onClick={handleImport} disabled={importing || !importUrl.trim()}>
                  {importing ? <span className="ar-spinner" /> : 'Extract recipe'}
                </button>
              </div>
            </>
          )}

          {method === 'paste' && (
            <>
              <h2 className="ar-import-title">Paste recipe text</h2>
              <p className="ar-import-hint">Paste from anywhere — we'll detect the title, ingredients, and steps.</p>
              <textarea
                className="ar-paste-area"
                placeholder="Paste recipe text here…"
                value={pasteText}
                onChange={e => { setPasteText(e.target.value); setImportError(''); }}
                rows={10}
                autoFocus
              />
              <button className="btn-primary ar-parse-btn" onClick={handleParseText} disabled={importing || !pasteText.trim()}>
                {importing ? <span className="ar-spinner" /> : 'Parse recipe'}
              </button>
            </>
          )}

          {importError && <p className="ar-import-error">{importError}</p>}
        </div>
      )}

      {/* ── Recipe form ─────────────────────────────────────── */}
      {!showImportPanel && (
        <>
          {imported && (
            <div className="ar-success-banner">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="8" fill="#2D9D5C"/><path d="M4.5 8.5l2.5 2.5 4.5-5" stroke="#fff" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>
              Recipe imported — review and save.
              <button className="ar-reimport" onClick={() => { setImported(false); setMethod(method === 'manual' ? 'url' : method); }}>Re-import</button>
            </div>
          )}

          <form className="add-recipe-form" onSubmit={handleSubmit}>
            <div className="add-recipe-form-grid">
              <label>
                Recipe name *
                <input type="text" value={form.recipe_name} onChange={e => setForm({...form, recipe_name: e.target.value})} required placeholder="e.g. Spaghetti Carbonara" />
              </label>
              <label>
                Cuisine
                <input type="text" value={form.cuisine} onChange={e => setForm({...form, cuisine: e.target.value})} placeholder="e.g. Italian" />
              </label>
              <div className="full-width">
                Category
                <ComboBox
                  value={form.category}
                  onChange={v => setForm(f => ({ ...f, category: v }))}
                  suggestions={categorySuggestions}
                  placeholder="e.g. Pasta"
                />
              </div>
              <div className="full-width">
                Tags
                <ComboBox
                  multi
                  value={form.tags}
                  onChange={v => setForm(f => ({ ...f, tags: v }))}
                  suggestions={tagSuggestions}
                  placeholder="Type a tag…"
                />
              </div>
              <label>
                Prep (min)
                <input type="number" value={form.prep_time} onChange={e => setForm({...form, prep_time: e.target.value})} min="0" />
              </label>
              <label>
                Cook (min)
                <input type="number" value={form.cook_time} onChange={e => setForm({...form, cook_time: e.target.value})} min="0" />
              </label>
              <label>
                Servings
                <input type="number" value={form.servings} onChange={e => setForm({...form, servings: e.target.value})} min="1" />
              </label>
              <label className="full-width">
                Image
                <div className="ar-image-row">
                  <input type="url" value={form.image_url} onChange={e => setForm({...form, image_url: e.target.value})} placeholder="https://…" />
                  <button type="button" className="ar-upload-btn" onClick={() => fileRef.current.click()} disabled={uploading}>
                    {uploading ? '…' : '↑ Upload'}
                  </button>
                  <input ref={fileRef} type="file" accept="image/*" style={{display:'none'}} onChange={handleImageUpload} />
                </div>
              </label>
              <div className="ar-toggle-row full-width">
                <div>
                  <span className="ar-toggle-label">Share publicly</span>
                  <span className="ar-toggle-sub">Show this recipe on Explore for others to discover</span>
                </div>
                <button
                  type="button"
                  className={`ar-toggle${form.is_public ? ' ar-toggle--on' : ''}`}
                  onClick={() => setForm(f => ({ ...f, is_public: !f.is_public }))}
                  role="switch"
                  aria-checked={form.is_public}
                />
              </div>

              <label className="full-width">
                Ingredients
                {ingredients.map((ing, idx) => (
                  ing.is_section ? (
                    <div key={idx} className="ingredient-section-row">
                      <span className="ingredient-section-label">Section</span>
                      <input className="ingredient-section-input" placeholder="e.g. Frosting" value={ing.name} onChange={e => updateIng(idx, 'name', e.target.value)} />
                      <button type="button" className="btn-remove-ingredient" onClick={() => setIngredients(ingredients.filter((_, i) => i !== idx))}>✕</button>
                    </div>
                  ) : (
                  <div key={idx} className="ingredient-row">
                    <input type="text" placeholder="Name" value={ing.name} onChange={e => updateIng(idx, 'name', e.target.value)} />
                    <input type="text" placeholder="Qty" value={ing.quantity} onChange={e => updateIng(idx, 'quantity', e.target.value)} />
                    <input type="text" placeholder="Unit" value={ing.unit} onChange={e => updateIng(idx, 'unit', e.target.value)} />
                    {ingredients.length > 1 && (
                      <button type="button" className="btn-remove-ingredient" onClick={() => setIngredients(ingredients.filter((_, i) => i !== idx))}>✕</button>
                    )}
                  </div>
                  )
                ))}
                <div className="ing-add-row">
                  <button type="button" className="btn-add-ingredient" onClick={() => setIngredients([...ingredients, { name: '', quantity: '', unit: '', is_section: false }])}>
                    + Add ingredient
                  </button>
                  <button type="button" className="btn-add-section" onClick={() => setIngredients([...ingredients, { name: '', quantity: '', unit: '', is_section: true }])}>
                    + Add section
                  </button>
                </div>
              </label>

              <div className="full-width">
                Instructions
                <div className="ar-steps">
                  {steps.map((step, idx) => (
                    <div
                      key={idx}
                      className={`ar-step-row${dragOver === idx ? ' ar-step-row--drag-over' : ''}`}
                      draggable
                      onDragStart={() => handleStepDragStart(idx)}
                      onDragOver={e => handleStepDragOver(e, idx)}
                      onDrop={() => handleStepDrop(idx)}
                      onDragEnd={() => { dragIdx.current = null; setDragOver(null); }}
                    >
                      <span className="ar-drag-handle">⠿</span>
                      <div className="ar-step-arrows">
                        <button type="button" className="ar-step-arrow" disabled={idx === 0}
                          onClick={() => { const n=[...steps]; [n[idx-1],n[idx]]=[n[idx],n[idx-1]]; setSteps(n); }}>▲</button>
                        <button type="button" className="ar-step-arrow" disabled={idx === steps.length - 1}
                          onClick={() => { const n=[...steps]; [n[idx],n[idx+1]]=[n[idx+1],n[idx]]; setSteps(n); }}>▼</button>
                      </div>
                      <span className="ar-step-num">{idx + 1}</span>
                      <textarea
                        className="ar-step-input"
                        placeholder={`Step ${idx + 1}…`}
                        value={step}
                        rows={2}
                        onChange={e => updateStep(idx, e.target.value)}
                      />
                      {steps.length > 1 && (
                        <button type="button" className="btn-remove-ingredient" onClick={() => setSteps(steps.filter((_, i) => i !== idx))}>✕</button>
                      )}
                    </div>
                  ))}
                  <button type="button" className="btn-add-ingredient" onClick={() => setSteps([...steps, ''])}>
                    + Add step
                  </button>
                </div>
              </div>
            </div>

            <div className="add-recipe-actions">
              <button type="submit" className="btn-primary" disabled={submitting}>
                {submitting ? 'Saving…' : 'Save Recipe'}
              </button>
              <button type="button" className="btn-ghost" onClick={() => navigate('/recipes')}>Cancel</button>
            </div>
          </form>
        </>
      )}
    </div>
  );
}

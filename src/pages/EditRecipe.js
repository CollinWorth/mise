import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/AddRecipePage.css';

const SUGGESTED_CATEGORIES = [
  'Soup','Stew','Chili','Salad','Bowl','Pasta','Rice','Curry','Stir-fry',
  'Tacos','Burger','Pizza','Sandwich','Wrap','Roast','Grilled','Seafood',
  'Breakfast','Brunch','Eggs','Pancakes','Oatmeal','Smoothie',
  'Snack','Appetizer','Side dish','Dip','Bread','Cake','Cookies',
  'Muffins','Pie','Dessert','Drink',
];

const SUGGESTED_TAGS = [
  'quick','easy','healthy','vegetarian','vegan','gluten-free',
  'dairy-free','spicy','meal prep','high-protein','low-carb',
  'keto','comfort food','weeknight','kid-friendly','budget-friendly',
];

function EditRecipe({ user }) {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form, setForm] = useState(null);
  const [ingredients, setIngredients] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);
  const [tagInput, setTagInput] = useState('');

  useEffect(() => {
    apiFetch(`/recipes/${id}`)
      .then(r => r.ok ? r.json() : null)
      .then(recipe => {
        if (!recipe) { navigate('/recipes'); return; }
        setForm({
          recipe_name: recipe.recipe_name || '',
          instructions: recipe.instructions || '',
          prep_time: recipe.prep_time ?? '',
          cook_time: recipe.cook_time ?? '',
          servings: recipe.servings ?? '',
          cuisine:  recipe.cuisine  || '',
          category: recipe.category || '',
          tags:     recipe.tags     || '',
          image_url: recipe.image_url || '',
          user_id: recipe.user_id || user?.id || user?._id || '',
        });
        setIngredients(
          recipe.ingredients?.length
            ? recipe.ingredients.map(i => ({ name: i.name || '', quantity: i.quantity || '', unit: i.unit || '' }))
            : [{ name: '', quantity: '', unit: '' }]
        );
        setLoading(false);
      });
  }, [id]);

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleIngredientChange = (idx, e) => {
    setIngredients(ingredients.map((ing, i) =>
      i === idx ? { ...ing, [e.target.name]: e.target.value } : ing
    ));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    const recipe = {
      ...form,
      ingredients: ingredients.map(ing => ({ name: ing.name, quantity: ing.quantity, unit: ing.unit })),
      prep_time: form.prep_time ? Number(form.prep_time) : undefined,
      cook_time: form.cook_time ? Number(form.cook_time) : undefined,
      servings: form.servings ? Number(form.servings) : undefined,
    };
    try {
      const response = await apiFetch(`/recipes/${id}`, {
        method: 'PUT',
        body: JSON.stringify(recipe),
      });
      if (response.ok) {
        navigate(`/recipes/${id}`);
      } else {
        alert('Failed to save changes');
      }
    } catch (err) {
      alert('Error: ' + err.message);
    }
    setSubmitting(false);
  };

  const currentTags = form?.tags ? form.tags.split(',').map(t => t.trim()).filter(Boolean) : [];
  const addTag = tag => {
    const t = tag.trim().toLowerCase();
    if (!t || currentTags.map(x => x.toLowerCase()).includes(t)) return;
    setForm(f => ({ ...f, tags: [...currentTags, t].join(', ') }));
  };
  const removeTag = tag => setForm(f => ({ ...f, tags: currentTags.filter(t => t !== tag).join(', ') }));

  if (loading) return <div className="page"><p>Loading…</p></div>;

  return (
    <div className="page">
      <div className="page-header">
        <h1>Edit Recipe</h1>
        <button className="btn-ghost" onClick={() => navigate(`/recipes/${id}`)}>Cancel</button>
      </div>

      <form className="add-recipe-form" onSubmit={handleSubmit}>
        <div className="add-recipe-form-grid">
          <label>
            Title
            <input type="text" name="recipe_name" value={form.recipe_name} onChange={handleChange} required />
          </label>
          <label>
            Cuisine
            <input type="text" name="cuisine" value={form.cuisine} onChange={handleChange} />
          </label>
          <div style={{display:'flex',flexDirection:'column',gap:'var(--space-2)',fontSize:'var(--text-xs)',fontWeight:600,letterSpacing:'0.04em',textTransform:'uppercase',color:'var(--text-secondary)',gridColumn:'1/-1'}}>
            Category
            <div className="ar-tag-suggestions">
              {SUGGESTED_CATEGORIES.map(cat => (
                <button key={cat} type="button"
                  className={`ar-tag-suggest${form.category === cat ? ' ar-tag-suggest--active' : ''}`}
                  onClick={() => setForm(f => ({ ...f, category: f.category === cat ? '' : cat }))}>
                  {cat}
                </button>
              ))}
            </div>
            <input type="text" value={form.category || ''} onChange={e => setForm(f => ({...f, category: e.target.value}))} placeholder="Or type a custom category…" style={{textTransform:'none',letterSpacing:'normal',fontSize:'var(--text-sm)',fontWeight:'normal'}} />
          </div>
          <div style={{display:'flex',flexDirection:'column',gap:'var(--space-2)',fontSize:'var(--text-xs)',fontWeight:600,letterSpacing:'0.04em',textTransform:'uppercase',color:'var(--text-secondary)'}}>
            Tags
            <div className="ar-tag-suggestions">
              {SUGGESTED_TAGS.filter(t => !currentTags.map(x => x.toLowerCase()).includes(t)).map(t => (
                <button key={t} type="button" className="ar-tag-suggest" onClick={() => addTag(t)}>+ {t}</button>
              ))}
            </div>
            <div className="ar-tag-input-row">
              {currentTags.map(t => (
                <span key={t} className="ar-tag-pill">
                  {t}<button type="button" className="ar-tag-pill-remove" onClick={() => removeTag(t)}>×</button>
                </span>
              ))}
              <input
                type="text"
                className="ar-tag-text-input"
                placeholder={currentTags.length ? 'Add more…' : 'Type a tag…'}
                value={tagInput}
                onChange={e => setTagInput(e.target.value)}
                onKeyDown={e => {
                  if ((e.key === 'Enter' || e.key === ',') && tagInput.trim()) {
                    e.preventDefault(); addTag(tagInput); setTagInput('');
                  }
                }}
              />
            </div>
          </div>
          <label>
            Image URL
            <input type="text" name="image_url" value={form.image_url} onChange={handleChange} />
          </label>
          <div className="ar-label ar-col-2 ar-toggle-row" style={{gridColumn:'1/-1'}}>
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
          <label>
            Prep Time (min)
            <input type="number" name="prep_time" value={form.prep_time} onChange={handleChange} min="0" />
          </label>
          <label>
            Cook Time (min)
            <input type="number" name="cook_time" value={form.cook_time} onChange={handleChange} min="0" />
          </label>
          <label>
            Servings
            <input type="number" name="servings" value={form.servings} onChange={handleChange} min="1" />
          </label>

          <label className="full-width">
            Ingredients
            {ingredients.map((ingredient, idx) => (
              <div key={idx} className="ingredient-row">
                <input type="text" name="name" placeholder="Name" value={ingredient.name}
                  onChange={(e) => handleIngredientChange(idx, e)} />
                <input type="text" name="quantity" placeholder="Qty" value={ingredient.quantity}
                  onChange={(e) => handleIngredientChange(idx, e)} />
                <input type="text" name="unit" placeholder="Unit" value={ingredient.unit}
                  onChange={(e) => handleIngredientChange(idx, e)} />
                {ingredients.length > 1 && (
                  <button type="button" className="btn-remove-ingredient"
                    onClick={() => setIngredients(ingredients.filter((_, i) => i !== idx))}>✕</button>
                )}
              </div>
            ))}
            <button type="button" className="btn-add-ingredient"
              onClick={() => setIngredients([...ingredients, { name: '', quantity: '', unit: '' }])}>
              + Add ingredient
            </button>
          </label>

          <label className="full-width">
            Instructions
            <textarea name="instructions" value={form.instructions} onChange={handleChange} rows={7} />
          </label>
        </div>

        <div className="add-recipe-actions">
          <button type="submit" className="btn-primary" disabled={submitting}>
            {submitting ? 'Saving…' : 'Save Changes'}
          </button>
          <button type="button" className="btn-ghost" onClick={() => navigate(`/recipes/${id}`)}>Cancel</button>
        </div>
      </form>
    </div>
  );
}

export default EditRecipe;

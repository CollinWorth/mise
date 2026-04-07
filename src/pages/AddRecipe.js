import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/AddRecipePage.css';

function AddRecipe({ user }) {
  const navigate = useNavigate();
  const [form, setForm] = useState({
    recipe_name: '',
    instructions: '',
    prep_time: '',
    cook_time: '',
    servings: '',
    cuisine: '',
    tags: '',
    image_url: '',
    user_id: user?.id || user?._id || '',
  });
  const [ingredients, setIngredients] = useState([{ name: '', quantity: '', unit: '' }]);
  const [submitting, setSubmitting] = useState(false);
  const [importUrl, setImportUrl] = useState('');
  const [importing, setImporting] = useState(false);
  const [importError, setImportError] = useState('');

  useEffect(() => {
    if (user && (user.id || user._id)) {
      setForm((f) => ({ ...f, user_id: user.id || user._id }));
    }
  }, [user]);

  const handleImport = async () => {
    if (!importUrl.trim()) return;
    setImporting(true);
    setImportError('');
    try {
      const r = await apiFetch('/recipes/scrape', {
        method: 'POST',
        body: JSON.stringify({ url: importUrl.trim() }),
      });
      if (!r.ok) {
        const err = await r.json();
        setImportError(err.detail || 'Failed to import recipe');
        setImporting(false);
        return;
      }
      const data = await r.json();
      setForm(f => ({
        ...f,
        recipe_name: data.recipe_name || f.recipe_name,
        cuisine: data.cuisine || f.cuisine,
        image_url: data.image_url || f.image_url,
        prep_time: data.prep_time || f.prep_time,
        cook_time: data.cook_time || f.cook_time,
        servings: data.servings || f.servings,
        instructions: data.instructions || f.instructions,
        tags: data.tags || f.tags,
      }));
      if (data.ingredients && data.ingredients.length > 0) {
        setIngredients(data.ingredients);
      }
      setImportUrl('');
    } catch (e) {
      setImportError('Could not reach the server');
    }
    setImporting(false);
  };

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
      ingredients: ingredients.map((ing) => ({ name: ing.name, quantity: ing.quantity, unit: ing.unit })),
      prep_time: form.prep_time ? Number(form.prep_time) : undefined,
      cook_time: form.cook_time ? Number(form.cook_time) : undefined,
      servings: form.servings ? Number(form.servings) : undefined,
    };
    try {
      const response = await apiFetch('/recipes', {
        method: 'POST',
        body: JSON.stringify(recipe),
      });
      if (response.ok) {
        navigate('/recipes');
      } else {
        alert('Failed to add recipe');
      }
    } catch (err) {
      alert('Error: ' + err.message);
    }
    setSubmitting(false);
  };

  return (
    <div className="page">
      <div className="page-header">
        <h1>Add Recipe</h1>
        <button className="btn-ghost" onClick={() => navigate('/recipes')}>Cancel</button>
      </div>

      <div className="import-url-bar">
        <input
          type="url"
          className="import-url-input"
          placeholder="Paste a recipe URL to import…"
          value={importUrl}
          onChange={e => { setImportUrl(e.target.value); setImportError(''); }}
          onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), handleImport())}
        />
        <button
          type="button"
          className="btn-primary"
          onClick={handleImport}
          disabled={importing || !importUrl.trim()}
        >
          {importing ? 'Importing…' : 'Import'}
        </button>
      </div>
      {importError && <p className="import-error">{importError}</p>}

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
          <label>
            Tags
            <input type="text" name="tags" value={form.tags} onChange={handleChange} placeholder="comma separated" />
          </label>
          <label>
            Image URL
            <input type="text" name="image_url" value={form.image_url} onChange={handleChange} />
          </label>
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
                  onChange={(e) => handleIngredientChange(idx, e)} required />
                <input type="text" name="quantity" placeholder="Qty" value={ingredient.quantity}
                  onChange={(e) => handleIngredientChange(idx, e)} required />
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
            <textarea name="instructions" value={form.instructions} onChange={handleChange} required rows={7} />
          </label>
        </div>

        <div className="add-recipe-actions">
          <button type="submit" className="btn-primary" disabled={submitting}>
            {submitting ? 'Saving...' : 'Save Recipe'}
          </button>
          <button type="button" className="btn-ghost" onClick={() => navigate('/recipes')}>Cancel</button>
        </div>
      </form>
    </div>
  );
}

export default AddRecipe;

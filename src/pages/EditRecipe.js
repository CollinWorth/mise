import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/AddRecipePage.css';

function EditRecipe({ user }) {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form, setForm] = useState(null);
  const [ingredients, setIngredients] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);

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
          cuisine: recipe.cuisine || '',
          tags: recipe.tags || '',
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

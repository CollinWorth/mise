import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import '../App.css';
import './css/Recipes.css';
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

  const [ingredients, setIngredients] = useState([
    { name: '', quantity: '', unit: '' }
  ]);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (user && (user.id || user._id)) {
      setForm(f => ({ ...f, user_id: user.id || user._id }));
    }
  }, [user]);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleIngredientChange = (idx, e) => {
    const newIngredients = ingredients.map((ing, i) =>
      i === idx ? { ...ing, [e.target.name]: e.target.value } : ing
    );
    setIngredients(newIngredients);
  };

  const addIngredient = () => {
    setIngredients([...ingredients, { name: '', quantity: '', unit: '' }]);
  };

  const removeIngredient = (idx) => {
    setIngredients(ingredients.filter((_, i) => i !== idx));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitting(true);

    const endpoint = 'http://localhost:8000/recipes';
    const recipe = {
      recipe_name: form.recipe_name,
      ingredients: ingredients.map(ing => ({
        name: ing.name,
        quantity: ing.quantity,
        unit: ing.unit,
      })),
      instructions: form.instructions,
      prep_time: form.prep_time ? Number(form.prep_time) : undefined,
      cook_time: form.cook_time ? Number(form.cook_time) : undefined,
      servings: form.servings ? Number(form.servings) : undefined,
      cuisine: form.cuisine,
      tags: form.tags,
      image_url: form.image_url,
      user_id: form.user_id,
    };

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
    <div className="add-recipe-page-wrapper">
      <div className="add-recipe-header">
        <h1>Add a New Recipe</h1>
        <button className="add-recipe-cancel-btn" onClick={() => navigate('/recipes')}>Cancel</button>
      </div>
      <form className="add-recipe-form-page" onSubmit={handleSubmit}>
        <div className="add-recipe-form-main">
          <div className="add-recipe-form-section">
            <label>
              <span>Title</span>
              <input type="text" name="recipe_name" value={form.recipe_name} onChange={handleChange} required />
            </label>
            <label>
              <span>Cuisine</span>
              <input type="text" name="cuisine" value={form.cuisine} onChange={handleChange} />
            </label>
            <label>
              <span>Tags</span>
              <input type="text" name="tags" value={form.tags} onChange={handleChange} placeholder="comma separated" />
            </label>
            <label>
              <span>Image URL</span>
              <input type="text" name="image_url" value={form.image_url} onChange={handleChange} />
            </label>
            <label>
              <span>Prep Time (min)</span>
              <input type="number" name="prep_time" value={form.prep_time} onChange={handleChange} min="0" />
            </label>
            <label>
              <span>Cook Time (min)</span>
              <input type="number" name="cook_time" value={form.cook_time} onChange={handleChange} min="0" />
            </label>
            <label>
              <span>Servings</span>
              <input type="number" name="servings" value={form.servings} onChange={handleChange} min="1" />
            </label>
          </div>
          <div className="add-recipe-form-section">
            <label>
              <span>Ingredients</span>
              {ingredients.map((ingredient, idx) => (
                <div key={idx} className="ingredient-row">
                  <input
                    type="text"
                    name="name"
                    placeholder="Name"
                    value={ingredient.name}
                    onChange={e => handleIngredientChange(idx, e)}
                    required
                  />
                  <input
                    type="text"
                    name="quantity"
                    placeholder="Quantity"
                    value={ingredient.quantity}
                    onChange={e => handleIngredientChange(idx, e)}
                    required
                  />
                  <input
                    type="text"
                    name="unit"
                    placeholder="Unit"
                    value={ingredient.unit}
                    onChange={e => handleIngredientChange(idx, e)}
                  />
                  {ingredients.length > 1 && (
                    <button type="button" className="remove-ingredient-btn" onClick={() => removeIngredient(idx)} title="Remove">✕</button>
                  )}
                </div>
              ))}
              <button type="button" className="add-ingredient-btn" onClick={addIngredient}>+ Add Ingredient</button>
            </label>
            <label>
              <span>Instructions</span>
              <textarea name="instructions" value={form.instructions} onChange={handleChange} required rows={7} />
            </label>
          </div>
        </div>
        <button type="submit" className="add-recipe-submit-btn" disabled={submitting}>
          {submitting ? 'Adding...' : 'Add Recipe'}
        </button>
      </form>
    </div>
  );
}

export default AddRecipe;
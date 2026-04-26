import React, { useState, useEffect, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
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

function EditRecipe({ user }) {
  const { id } = useParams();
  const navigate = useNavigate();
  const [form, setForm] = useState(null);
  const [ingredients, setIngredients] = useState([]);
  const [steps, setSteps] = useState(['']);
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);
  const [isRemix, setIsRemix] = useState(false);
  const [originalName, setOriginalName] = useState('');
  const [categorySuggestions, setCategorySuggestions] = useState(BASE_CATEGORIES);
  const [tagSuggestions, setTagSuggestions]           = useState(BASE_TAGS);
  const stepRefs = useRef([]);

  const autoResize = el => {
    if (!el) return;
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  };

  useEffect(() => {
    apiFetch(`/recipes/${id}`)
      .then(r => r.ok ? r.json() : null)
      .then(recipe => {
        if (!recipe) { navigate('/recipes'); return; }
        setIsRemix(!!recipe.is_modified);
        setOriginalName(recipe.original_recipe_name || 'the original recipe');
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
          is_public: recipe.is_public ?? true,
          user_id: recipe.user_id || user?.id || user?._id || '',
        });
        setIngredients(
          recipe.ingredients?.length
            ? recipe.ingredients.map(i => ({ name: i.name || '', quantity: i.quantity || '', unit: i.unit || '' }))
            : [{ name: '', quantity: '', unit: '' }]
        );
        setSteps(
          recipe.instructions
            ? recipe.instructions.split('\n').filter(s => s.trim())
            : ['']
        );
        setLoading(false);
      });
  }, [id]);

  useEffect(() => {
    if (!loading) stepRefs.current.forEach(autoResize);
  }, [loading]);

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
      instructions: steps.filter(s => s.trim()).join('\n'),
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
          <div className="full-width">
            Category
            <ComboBox
              value={form.category || ''}
              onChange={v => setForm(f => ({ ...f, category: v }))}
              suggestions={categorySuggestions}
              placeholder="e.g. Pasta"
            />
          </div>
          <div className="full-width">
            Tags
            <ComboBox
              multi
              value={form.tags || ''}
              onChange={v => setForm(f => ({ ...f, tags: v }))}
              suggestions={tagSuggestions}
              placeholder="Type a tag…"
            />
          </div>
          <label>
            Image URL
            <input type="text" name="image_url" value={form.image_url} onChange={handleChange} />
          </label>
          <div className="ar-toggle-row full-width">
            <div>
              <span className="ar-toggle-label">{isRemix ? 'Share as a version' : 'Share publicly'}</span>
              <span className="ar-toggle-sub">{isRemix ? `Show this as a version of "${originalName}" on its recipe page` : 'Show this recipe on Explore for others to discover'}</span>
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

          <div className="full-width">
            Instructions
            <div className="ar-steps">
              {steps.map((step, idx) => (
                <div key={idx} className="ar-step-row">
                  <span className="ar-step-num">{idx + 1}</span>
                  <textarea
                    className="ar-step-input"
                    ref={el => { stepRefs.current[idx] = el; }}
                    value={step}
                    placeholder={`Step ${idx + 1}…`}
                    onChange={e => { autoResize(e.target); setSteps(steps.map((s, i) => i === idx ? e.target.value : s)); }}
                  />
                  {steps.length > 1 && (
                    <button type="button" className="btn-remove-ingredient"
                      onClick={() => setSteps(steps.filter((_, i) => i !== idx))}>✕</button>
                  )}
                </div>
              ))}
            </div>
            <button type="button" className="btn-add-ingredient"
              onClick={() => setSteps([...steps, ''])}>+ Add step</button>
          </div>
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

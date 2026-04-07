import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/RecipeDetails.css';

function RecipeDetails() {
  const { id } = useParams();
  const [recipe, setRecipe] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchRecipe = async () => {
      try {
        const response = await apiFetch(`/recipes/${id}`);
        if (response.ok) setRecipe(await response.json());
      } catch (err) {
        console.error('Error fetching recipe:', err);
      }
      setLoading(false);
    };
    fetchRecipe();
  }, [id]);

  const handleDelete = async () => {
    if (!window.confirm('Delete this recipe?')) return;
    try {
      const response = await apiFetch(`/recipes/${id}`, { method: 'DELETE' });
      if (response.ok) navigate('/recipes');
      else alert('Failed to delete recipe');
    } catch (err) {
      console.error('Error deleting recipe:', err);
    }
  };

  if (loading) return <div className="page"><p>Loading...</p></div>;
  if (!recipe) return <div className="page"><p>Recipe not found.</p></div>;

  return (
    <div className="page">
      <div className="recipe-details">
        {recipe.image_url && (
          <div className="recipe-details-hero">
            <img src={recipe.image_url} alt={recipe.recipe_name} />
          </div>
        )}

        <h1 className="recipe-details-title">{recipe.recipe_name}</h1>

        <div className="recipe-details-meta">
          {recipe.prep_time && <span>Prep {recipe.prep_time}m</span>}
          {recipe.cook_time && <span>Cook {recipe.cook_time}m</span>}
          {recipe.servings && <span>Serves {recipe.servings}</span>}
        </div>

        {(recipe.cuisine || recipe.tags) && (
          <div className="recipe-details-badges">
            {recipe.cuisine && <span className="badge">{recipe.cuisine}</span>}
            {recipe.tags && <span className="badge">{recipe.tags}</span>}
          </div>
        )}

        <h2>Ingredients</h2>
        <ul>
          {recipe.ingredients.map((ing, idx) => (
            <li key={idx}>{ing.quantity} {ing.unit} {ing.name}</li>
          ))}
        </ul>

        <h2>Instructions</h2>
        <p className="recipe-details-instructions">{recipe.instructions}</p>

        <div className="recipe-details-actions">
          <button className="btn-ghost" onClick={() => navigate('/recipes')}>← Back</button>
          <button className="btn-ghost" onClick={() => navigate(`/recipes/${id}/edit`)}>Edit</button>
          <button className="btn-danger" onClick={handleDelete}>Delete Recipe</button>
        </div>
      </div>
    </div>
  );
}

export default RecipeDetails;

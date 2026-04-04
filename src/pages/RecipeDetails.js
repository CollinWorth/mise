import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import './css/RecipeDetails.css';

function RecipeDetails() {
  const { id } = useParams(); // Get the recipe ID from the URL
  const [recipe, setRecipe] = useState(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate(); // For navigation

  useEffect(() => {
    const fetchRecipe = async () => {
      try {
        const response = await fetch(`http://localhost:8000/recipes/${id}`);
        if (response.ok) {
          const data = await response.json();
          setRecipe(data);
        } else {
          console.error('Failed to fetch recipe details');
        }
      } catch (err) {
        console.error('Error fetching recipe:', err);
      }
      setLoading(false);
    };

    fetchRecipe();
  }, [id]);

  const handleDelete = async () => {
    const confirmDelete = window.confirm('Are you sure you want to delete this recipe?');
    if (!confirmDelete) return;

    try {
      const response = await fetch(`http://localhost:8000/recipes/${id}`, {
        method: 'DELETE',
      });
      if (response.ok) {
        alert('Recipe deleted successfully');
        navigate('/recipes'); // Navigate back to the recipes list
      } else {
        alert('Failed to delete recipe');
      }
    } catch (err) {
      console.error('Error deleting recipe:', err);
      alert('An error occurred while deleting the recipe');
    }
  };

  const handleBack = () => {
    navigate('/recipes'); // Navigate back to the recipes list
  };

  if (loading) return <div>Loading recipe...</div>;
  if (!recipe) return <div>Recipe not found</div>;

  return (
    <div className="recipe-details">
      <button onClick={handleBack} className="back-button">Back</button>
      <h1>{recipe.recipe_name}</h1>
      <p><strong>Cuisine:</strong> {recipe.cuisine}</p>
      <p><strong>Tags:</strong> {recipe.tags}</p>
      <p><strong>Prep Time:</strong> {recipe.prep_time} min</p>
      <p><strong>Cook Time:</strong> {recipe.cook_time} min</p>
      <p><strong>Servings:</strong> {recipe.servings}</p>
      <h2>Ingredients</h2>
      <ul>
        {recipe.ingredients.map((ing, idx) => (
          <li key={idx}>{ing.quantity} {ing.unit} {ing.name}</li>
        ))}
      </ul>
      <h2>Instructions</h2>
      <p>{recipe.instructions}</p>
      {recipe.image_url && <img src={recipe.image_url} alt={recipe.recipe_name} />}
      <button onClick={handleDelete} className="delete-button">Delete Recipe</button>
    </div>
  );
}

export default RecipeDetails;
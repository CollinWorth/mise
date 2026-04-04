import React, { useState, useEffect } from 'react';
import '../App.css';
import './css/Recipes.css';
import SearchBar from '../components/SearchBar.js';
import { useNavigate } from 'react-router-dom';

function Recipes({ user }) {
  const [recipes, setRecipes] = useState([]);
  const [filteredRecipes, setFilteredRecipes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const fetchRecipes = async () => {
      if (!user || !(user.id || user._id)) {
        setRecipes([]);
        setFilteredRecipes([]);
        setLoading(false);
        return;
      }
      setLoading(true);
      try {
        const userId = user.id || user._id;
        const response = await fetch(`http://localhost:8000/recipes/user/${userId}`);
        if (response.ok) {
          const data = await response.json();
          setRecipes(data);
          setFilteredRecipes(data);
        } else {
          setRecipes([]);
          setFilteredRecipes([]);
        }
      } catch (err) {
        setRecipes([]);
        setFilteredRecipes([]);
      }
      setLoading(false);
    };
    fetchRecipes();
  }, [user]);

  const handleSearch = (query) => {
    setSearchQuery(query);
    const filtered = recipes.filter((recipe) =>
      recipe.recipe_name.toLowerCase().includes(query.toLowerCase())
    );
    setFilteredRecipes(filtered);
  };

  const handleRecipeClick = (id) => {
    navigate(`/recipes/${id}`);
  };

  return (
    <div className="recipes-page-wrapper">
      {/* Sticky Header */}
      <div className="recipes-header">
        <div className="add-recipe-button">
          <button onClick={() => navigate('/recipes/add')}>Add Recipe</button>
        </div>
        <SearchBar onSearch={handleSearch} />
      </div>

      {/* Main Grid Layout */}
      <div className="recipes-layout">
        {/* Left Sidebar */}
        <aside className="recipes-sidebar-left">
          <h3>Quick Filters</h3>
          <ul>
            <li>🌱 Vegetarian</li>
            <li>🔥 Quick Meals</li>
            <li>🍲 Soups</li>
            <li>🌍 World Cuisine</li>
          </ul>
        </aside>

        {/* Main Recipe Area */}
        <main className="recipes">
          <h1>Your Recipes</h1>
          <p>These are recipes you have added.</p>
          <div className="recipe-list">
            {loading ? (
              <div>Loading recipes...</div>
            ) : filteredRecipes.length === 0 ? (
              <div>No recipes found.</div>
            ) : (
              filteredRecipes.map((recipe, idx) => (
                <div
                  className="recipe-card"
                  key={recipe._id || recipe.id || idx}
                  onClick={() => handleRecipeClick(recipe._id || recipe.id)}
                  style={{ cursor: 'pointer' }}
                >
                  <h2>{recipe.recipe_name}</h2>
                  <div style={{ margin: "10px 0" }}>
                    {recipe.cuisine && (
                      <span className="recipe-badge">{recipe.cuisine}</span>
                    )}
                    {recipe.tags && (
                      <span className="recipe-badge" style={{ marginLeft: 8 }}>{recipe.tags}</span>
                    )}
                  </div>
                  <div className="recipe-details-row">
                    {recipe.prep_time && (
                      <span><strong>Prep:</strong> {recipe.prep_time} min</span>
                    )}
                    {recipe.cook_time && (
                      <span><strong>Cook:</strong> {recipe.cook_time} min</span>
                    )}
                    {recipe.servings && (
                      <span><strong>Servings:</strong> {recipe.servings}</span>
                    )}
                  </div>
                  {recipe.image_url && (
                    <img
                      src={recipe.image_url}
                      alt={recipe.recipe_name}
                      className="recipe-card-image"
                    />
                  )}
                </div>
              ))
            )}
          </div>
        </main>

        {/* Right Sidebar */}
        <aside className="recipes-sidebar-right">
          <h3>Tips & Ideas</h3>
          <p>💡 Try organizing recipes by season or occasion.</p>
          <p>📷 Click any recipe to see or edit details.</p>
        </aside>
      </div>
    </div>
  );
}

export default Recipes;
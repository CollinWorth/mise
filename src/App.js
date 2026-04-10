import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import './styles/global.css';
import './App.css';
import { getStoredUser, setSession, clearSession } from './api';
import NavBar from './components/NavBar';
import Calendar from './pages/CalendarPage';
import Recipes from './pages/Recipes';
import RecipeDetails from './pages/RecipeDetails';
import Login from './pages/Login';
import Register from './pages/Register';
import GroceryList from './pages/GroceryList';
import AddRecipe from './pages/AddRecipe';
import EditRecipe from './pages/EditRecipe';
import CookMode from './pages/CookMode';
import ExplorePage from './pages/ExplorePage';
import ProfilePage from './pages/ProfilePage';
import FeedPage from './pages/FeedPage';
import UserProfilePage from './pages/UserProfilePage';

function App() {
  const [user, setUser] = useState(getStoredUser);

  const handleLogin = (token, userData) => {
    setSession(token, userData);
    setUser(userData);
  };

  const handleLogout = () => {
    clearSession();
    setUser(null);
  };

  return (
    <Router>
      <div className="App">
        <NavBar user={user} onLogout={handleLogout} />
        <Routes>
          <Route path="/" element={<Recipes user={user} />} />
          <Route path="/calendar" element={<Calendar user={user} />} />
          <Route path="/recipes" element={<Recipes user={user} />} />
          <Route path="/recipes/:id" element={<RecipeDetails user={user} />} />
          <Route path="/login" element={<Login onLogin={handleLogin} />} />
          <Route path="/register" element={<Register />} />
          <Route path="/grocery-list" element={<GroceryList user={user} />} />
          <Route path="/recipes/add" element={<AddRecipe user={user} />} />
          <Route path="/recipes/:id/edit" element={<EditRecipe user={user} />} />
          <Route path="/recipes/:id/cook" element={<CookMode />} />
          <Route path="/explore"    element={<ExplorePage user={user} />} />
          <Route path="/feed"       element={<FeedPage user={user} />} />
          <Route path="/profile"    element={<ProfilePage user={user} onLogout={handleLogout} />} />
          <Route path="/users/:id"  element={<UserProfilePage user={user} />} />
        </Routes>
      </div>
    </Router>
  );
}

export default App;

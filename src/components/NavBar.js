import React from 'react';
import { Link } from 'react-router-dom';
import './css/NavBar.css';

function NavBar({ user }) {
  return (
    <header className="header">
      <div className="header-top">
        <div className="logo">
          🥕 Harvest Pantry
        </div>
      </div>

      <nav className="navbar">
        <ul className="navbar-list">
          <li className="navbar-item"><Link to="/">Home</Link></li>
          {user && <li className="navbar-item"><Link to="/calendar">Calendar</Link></li>}
          {user && <li className="navbar-item"><Link to="/recipes">Recipes</Link></li>}
          {user && <li className="navbar-item"><Link to="/grocery-list">Grocery List</Link></li>}
          <li className="navbar-item"><Link to="/contact">Contact</Link></li>
          {!user && <li className="navbar-item"><Link to="/login">Login</Link></li>}
          {!user && <li className="navbar-item"><Link to="/register">Register</Link></li>}
        </ul>
      </nav>
    </header>
  );
}

export default NavBar;
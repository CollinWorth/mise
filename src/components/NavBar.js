import React from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import './css/NavBar.css';

function NavBar({ user, onLogout }) {
  const location = useLocation();
  const navigate = useNavigate();

  const handleLogout = () => {
    onLogout();
    navigate('/login');
  };

  return (
    <nav className="nav">
      <div className="nav-inner">
        <Link to="/" className="nav-logo">mise</Link>
        <div className="nav-links">
          {user && <NavLink to="/recipes" current={location.pathname}>Recipes</NavLink>}
          {user && <NavLink to="/calendar" current={location.pathname}>Planner</NavLink>}
          {user && <NavLink to="/grocery-list" current={location.pathname}>Grocery</NavLink>}
          {!user && <NavLink to="/login" current={location.pathname}>Login</NavLink>}
          {!user && <NavLink to="/register" current={location.pathname}>Register</NavLink>}
          {user && (
            <>
              <div className="nav-divider" />
              <span className="nav-user">{user.name?.split(' ')[0]}</span>
              <button className="nav-logout" onClick={handleLogout}>Sign out</button>
            </>
          )}
        </div>
      </div>
    </nav>
  );
}

function NavLink({ to, current, children }) {
  const active = current === to || (to !== '/' && current.startsWith(to));
  return (
    <Link to={to} className={`nav-link${active ? ' nav-link--active' : ''}`}>
      {children}
    </Link>
  );
}

export default NavBar;

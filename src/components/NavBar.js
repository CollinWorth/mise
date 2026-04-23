import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import './css/NavBar.css';

function NavBar({ user, onLogout }) {
  const location = useLocation();
  const navigate = useNavigate();
  const [profileOpen, setProfileOpen] = useState(false);
  const profileRef = useRef(null);

  const [theme, setTheme] = useState(() => localStorage.getItem('mise_theme') || 'light');

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem('mise_theme', theme);
  }, [theme]);

  useEffect(() => {
    const handler = (e) => {
      if (profileRef.current && !profileRef.current.contains(e.target)) {
        setProfileOpen(false);
      }
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const handleLogout = () => {
    onLogout();
    navigate('/login');
    setProfileOpen(false);
  };

  return (
    <nav className="nav">
      <div className="nav-inner">
        <Link to="/" className="nav-logo">mise</Link>
        <div className="nav-links">
          <NavLink to="/discover" current={location.pathname}>Discover</NavLink>
          {user && <NavLink to="/recipes"      current={location.pathname}>Recipes</NavLink>}
          {user && <NavLink to="/calendar"     current={location.pathname}>Planner</NavLink>}
          {user && <NavLink to="/grocery-list" current={location.pathname}>Grocery</NavLink>}
          {!user && <NavLink to="/login"    current={location.pathname}>Login</NavLink>}
          {!user && <NavLink to="/register" current={location.pathname}>Register</NavLink>}
          <button
            className="nav-theme-toggle"
            onClick={() => setTheme(t => t === 'dark' ? 'light' : 'dark')}
            aria-label="Toggle dark mode"
            title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            {theme === 'dark' ? '☀' : '☾'}
          </button>
          {user && (
            <>
              <div className="nav-divider" />
              <div className="nav-profile-wrap" ref={profileRef}>
                <button
                  className={`nav-avatar${profileOpen ? ' nav-avatar--open' : ''}`}
                  onClick={() => setProfileOpen(o => !o)}
                  aria-label="Profile menu"
                >
                  {user.name?.[0]?.toUpperCase() ?? '?'}
                </button>
                {profileOpen && (
                  <div className="nav-dropdown">
                    <div className="nav-dropdown-name">{user.name}</div>
                    <Link
                      to="/profile"
                      className="nav-dropdown-item"
                      onClick={() => setProfileOpen(false)}
                    >
                      Profile
                    </Link>
                    <Link
                      to="/settings"
                      className="nav-dropdown-item"
                      onClick={() => setProfileOpen(false)}
                    >
                      Settings
                    </Link>
                    <button className="nav-dropdown-item nav-dropdown-signout" onClick={handleLogout}>
                      Sign out
                    </button>
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </nav>
  );
}

const DISCOVER_ALIASES = ['/discover', '/explore', '/feed'];
function NavLink({ to, current, children }) {
  const isDiscover = to === '/discover' && DISCOVER_ALIASES.includes(current);
  const active = isDiscover || current === to || (to !== '/' && current.startsWith(to));
  return (
    <Link to={to} className={`nav-link${active ? ' nav-link--active' : ''}`}>
      {children}
    </Link>
  );
}

export default NavBar;

import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import './css/NavBar.css';

function NavBar({ user, onLogout }) {
  const location = useLocation();
  const navigate = useNavigate();
  const [profileOpen, setProfileOpen] = useState(false);
  const profileRef = useRef(null);

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
          {user && <NavLink to="/feed"         current={location.pathname}>Feed</NavLink>}
          {user && <NavLink to="/recipes"      current={location.pathname}>Recipes</NavLink>}
          {user && <NavLink to="/explore"      current={location.pathname}>Explore</NavLink>}
          {user && <NavLink to="/calendar"     current={location.pathname}>Planner</NavLink>}
          {user && <NavLink to="/grocery-list" current={location.pathname}>Grocery</NavLink>}
          {!user && <NavLink to="/login"    current={location.pathname}>Login</NavLink>}
          {!user && <NavLink to="/register" current={location.pathname}>Register</NavLink>}
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

function NavLink({ to, current, children }) {
  const active = current === to || (to !== '/' && current.startsWith(to));
  return (
    <Link to={to} className={`nav-link${active ? ' nav-link--active' : ''}`}>
      {children}
    </Link>
  );
}

export default NavBar;

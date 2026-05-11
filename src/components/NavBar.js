import React, { useState, useRef, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import './css/NavBar.css';

const DiscoverIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10"/>
    <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/>
  </svg>
);
const RecipesIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/>
    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>
  </svg>
);
const PlannerIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
    <line x1="16" y1="2" x2="16" y2="6"/>
    <line x1="8" y1="2" x2="8" y2="6"/>
    <line x1="3" y1="10" x2="21" y2="10"/>
  </svg>
);
const GroceryIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="9" cy="21" r="1"/>
    <circle cx="20" cy="21" r="1"/>
    <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"/>
  </svg>
);
const ProfileIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
    <circle cx="12" cy="7" r="4"/>
  </svg>
);
const LoginIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
    <polyline points="10 17 15 12 10 7"/>
    <line x1="15" y1="12" x2="3" y2="12"/>
  </svg>
);
const RegisterIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
    <circle cx="8.5" cy="7" r="4"/>
    <line x1="20" y1="8" x2="20" y2="14"/>
    <line x1="23" y1="11" x2="17" y2="11"/>
  </svg>
);

function NavBar({ user, onLogout }) {
  const location = useLocation();
  const navigate = useNavigate();
  const [profileOpen, setProfileOpen] = useState(false);
  const profileRef = useRef(null);
  const bottomProfileRef = useRef(null);

  const isCookMode = /\/recipes\/[^/]+\/cook/.test(location.pathname);

  useEffect(() => {
    const handler = (e) => {
      const inDesktop = profileRef.current?.contains(e.target);
      const inBottom = bottomProfileRef.current?.contains(e.target);
      if (!inDesktop && !inBottom) setProfileOpen(false);
    };
    document.addEventListener('mousedown', handler);
    document.addEventListener('touchstart', handler);
    return () => {
      document.removeEventListener('mousedown', handler);
      document.removeEventListener('touchstart', handler);
    };
  }, []);

  const handleLogout = () => {
    onLogout();
    navigate('/login');
    setProfileOpen(false);
  };

  if (isCookMode) return null;

  return (
    <>
      <nav className="nav">
        <div className="nav-inner">
          <Link to="/" className="nav-logo">mise</Link>
          <div className="nav-links">
            {user ? (
              <div className="nav-main-links">
                <NavLink to="/discover"     current={location.pathname} aliases={['/discover','/explore','/feed']}>Discover</NavLink>
                <NavLink to="/recipes"      current={location.pathname}>Recipes</NavLink>
                <NavLink to="/calendar"     current={location.pathname}>Planner</NavLink>
                <NavLink to="/grocery-list" current={location.pathname}>Grocery</NavLink>
              </div>
            ) : (
              <>
                <NavLink to="/discover" current={location.pathname} aliases={['/discover','/explore','/feed']}>Discover</NavLink>
                <NavLink to="/login"    current={location.pathname}>Login</NavLink>
                <NavLink to="/register" current={location.pathname}>Register</NavLink>
              </>
            )}
            {user && (
              <>
                <div className="nav-divider nav-divider--desktop" />
                <div className="nav-profile-wrap nav-profile-wrap--desktop" ref={profileRef}>
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
                      <Link to="/profile"  className="nav-dropdown-item" onClick={() => setProfileOpen(false)}>Profile</Link>
                      <Link to="/settings" className="nav-dropdown-item" onClick={() => setProfileOpen(false)}>Settings</Link>
                      <button className="nav-dropdown-item nav-dropdown-signout" onClick={handleLogout}>Sign out</button>
                    </div>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      </nav>

      <nav className="nav-bottom" aria-label="Main navigation">
        <BottomTab to="/discover" label="Discover" icon={<DiscoverIcon />} current={location.pathname} aliases={['/discover','/explore','/feed']} />
        {user ? (
          <>
            <BottomTab to="/recipes"      label="Recipes" icon={<RecipesIcon />} current={location.pathname} />
            <BottomTab to="/calendar"     label="Planner" icon={<PlannerIcon />} current={location.pathname} />
            <BottomTab to="/grocery-list" label="Grocery" icon={<GroceryIcon />} current={location.pathname} />
            <div className="nav-bottom-profile-wrap" ref={bottomProfileRef}>
              <button
                className={`nav-bottom-tab${profileOpen ? ' nav-bottom-tab--active' : ''}`}
                onClick={() => setProfileOpen(o => !o)}
                aria-label="Profile menu"
              >
                <span className="nav-bottom-icon"><ProfileIcon /></span>
                <span className="nav-bottom-label">Profile</span>
              </button>
              {profileOpen && (
                <div className="nav-dropdown nav-dropdown--up">
                  <div className="nav-dropdown-name">{user.name}</div>
                  <Link to="/profile"  className="nav-dropdown-item" onClick={() => setProfileOpen(false)}>Profile</Link>
                  <Link to="/settings" className="nav-dropdown-item" onClick={() => setProfileOpen(false)}>Settings</Link>
                  <button className="nav-dropdown-item nav-dropdown-signout" onClick={handleLogout}>Sign out</button>
                </div>
              )}
            </div>
          </>
        ) : (
          <>
            <BottomTab to="/login"    label="Login"   icon={<LoginIcon />}    current={location.pathname} />
            <BottomTab to="/register" label="Sign Up" icon={<RegisterIcon />} current={location.pathname} />
          </>
        )}
      </nav>
    </>
  );
}

function NavLink({ to, current, children, aliases = [] }) {
  const active = aliases.includes(current) || current === to || (to !== '/' && current.startsWith(to));
  return (
    <Link to={to} className={`nav-link${active ? ' nav-link--active' : ''}`}>
      {children}
    </Link>
  );
}

function BottomTab({ to, label, icon, current, aliases = [] }) {
  const active = aliases.includes(current) || current === to || (to !== '/' && current.startsWith(to));
  return (
    <Link to={to} className={`nav-bottom-tab${active ? ' nav-bottom-tab--active' : ''}`}>
      <span className="nav-bottom-icon">{icon}</span>
      <span className="nav-bottom-label">{label}</span>
    </Link>
  );
}

export default NavBar;

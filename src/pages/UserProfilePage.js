import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/UserProfilePage.css';
import './css/Recipes.css';

const CUISINE_PASTELS = {
  italian:'#F5EDE8', mexican:'#E9F2E9', japanese:'#F2EDF4',
  chinese:'#F5EDEC', indian:'#F5F0E8', american:'#EBF0F5',
  french:'#EEF0F8', thai:'#F3F2E7', mediterranean:'#E8F2EF',
  greek:'#EDF0F8', korean:'#F4EDF2',
};
const cuisinePastel = c => CUISINE_PASTELS[(c||'').toLowerCase()] || '#F2F0EB';
const totalTime = r => { const t = (r.prep_time||0)+(r.cook_time||0); return t > 0 ? `${t}m` : null; };

export default function UserProfilePage({ user: currentUser }) {
  const { id }        = useParams();
  const navigate      = useNavigate();
  const [profile, setProfile]         = useState(null);
  const [recipes, setRecipes]         = useState([]);
  const [isFollowing, setIsFollowing] = useState(false);
  const [followLoading, setFollowLoading] = useState(false);
  const [loading, setLoading]         = useState(true);

  const isOwnProfile = currentUser && (currentUser.id === id || currentUser._id === id);

  useEffect(() => {
    if (isOwnProfile) { navigate('/profile', { replace: true }); return; }

    Promise.all([
      apiFetch(`/users/${id}`).then(r => r.ok ? r.json() : null),
      apiFetch(`/users/${id}/recipes`).then(r => r.ok ? r.json() : []),
      currentUser ? apiFetch(`/follows/${id}/status`).then(r => r.ok ? r.json() : null) : Promise.resolve(null),
    ]).then(([prof, recs, followStatus]) => {
      setProfile(prof);
      setRecipes(recs || []);
      if (followStatus) setIsFollowing(followStatus.is_following);
      setLoading(false);
    }).catch(() => setLoading(false));
  }, [id, currentUser, isOwnProfile]);

  const handleFollow = async () => {
    if (!currentUser) { navigate('/login'); return; }
    setFollowLoading(true);
    try {
      if (isFollowing) {
        await apiFetch(`/follows/${id}`, { method: 'DELETE' });
        setIsFollowing(false);
        setProfile(p => ({ ...p, follower_count: (p.follower_count || 1) - 1 }));
      } else {
        await apiFetch(`/follows/${id}`, { method: 'POST', body: '{}' });
        setIsFollowing(true);
        setProfile(p => ({ ...p, follower_count: (p.follower_count || 0) + 1 }));
      }
    } catch {}
    setFollowLoading(false);
  };

  if (loading) return (
    <div className="up-page page">
      <div className="up-skeleton-header" />
    </div>
  );

  if (!profile) return (
    <div className="up-page page"><p>User not found.</p></div>
  );

  const initial = profile.name?.[0]?.toUpperCase() ?? '?';

  return (
    <div className="up-page page">

      {/* ── Profile header ── */}
      <div className="up-header">
        <div className="up-avatar">{initial}</div>
        <div className="up-info">
          <div className="up-name-row">
            <h1 className="up-name">{profile.name}</h1>
            <button
              className={`up-follow-btn${isFollowing ? ' up-follow-btn--following' : ''}`}
              onClick={handleFollow}
              disabled={followLoading}
            >
              {followLoading ? '…' : isFollowing ? 'Following' : 'Follow'}
            </button>
          </div>
          <div className="up-stats">
            <div className="up-stat">
              <span className="up-stat-num">{profile.public_recipe_count ?? recipes.length}</span>
              <span className="up-stat-label">recipes</span>
            </div>
            <div className="up-stat">
              <span className="up-stat-num">{profile.follower_count ?? 0}</span>
              <span className="up-stat-label">followers</span>
            </div>
            <div className="up-stat">
              <span className="up-stat-num">{profile.following_count ?? 0}</span>
              <span className="up-stat-label">following</span>
            </div>
          </div>
        </div>
      </div>

      {/* ── Recipe grid ── */}
      {recipes.length === 0 ? (
        <div className="up-empty">
          <p>No public recipes yet.</p>
        </div>
      ) : (
        <div className="recipe-grid">
          {recipes.map((recipe, idx) => (
            <div
              key={recipe._id || recipe.id || idx}
              className="recipe-card"
              onClick={() => navigate(`/recipes/${recipe._id || recipe.id}`)}
            >
              <div className="recipe-card-img">
                {recipe.image_url
                  ? <img src={recipe.image_url} alt={recipe.recipe_name} />
                  : <div className="recipe-placeholder" style={{background: cuisinePastel(recipe.cuisine)}} />
                }
                <div className="recipe-card-overlay">
                  <div className="recipe-card-tags">
                    {recipe.cuisine && <span className="recipe-overlay-badge">{recipe.cuisine}</span>}
                    {totalTime(recipe) && <span className="recipe-overlay-time">{totalTime(recipe)}</span>}
                  </div>
                  <div className="recipe-card-title">{recipe.recipe_name}</div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

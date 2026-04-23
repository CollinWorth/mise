import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/Login_Register.css';

function Login({ onLogin }) {
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const response = await apiFetch('/users/login', {
        method: 'POST',
        body: JSON.stringify(form),
      });
      if (response.ok) {
        const data = await response.json();
        onLogin(data.access_token, data.user);
        navigate('/');
      } else {
        const data = await response.json();
        setError(data.detail || 'Invalid email or password');
      }
    } catch (err) {
      setError('Login failed. Please try again.');
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-panel-left">
        <div className="auth-brand">
          <span className="auth-logo">mise</span>
          <p className="auth-tagline">Every great meal starts with a plan.</p>
        </div>
        <ul className="auth-features">
          <li><span className="auth-feature-dot" />Save and organize your recipes</li>
          <li><span className="auth-feature-dot" />Plan your week at a glance</li>
          <li><span className="auth-feature-dot" />Auto-generate grocery lists</li>
          <li><span className="auth-feature-dot" />Share recipes with friends</li>
        </ul>
      </div>

      <div className="auth-panel-right">
        <div className="auth-form-wrap">
          <h1 className="auth-heading">Welcome back</h1>
          <p className="auth-subtitle">Sign in to your mise account</p>
          <form className="auth-form" onSubmit={handleSubmit}>
            <label>
              Email
              <input type="email" name="email" value={form.email} onChange={handleChange} placeholder="you@example.com" required autoFocus />
            </label>
            <label>
              Password
              <input type="password" name="password" value={form.password} onChange={handleChange} placeholder="••••••••" required />
            </label>
            {error && <p className="auth-error">{error}</p>}
            <button type="submit" className="auth-submit">Sign in</button>
          </form>
          <p className="auth-footer">
            No account? <Link to="/register">Create one free</Link>
          </p>
        </div>
      </div>
    </div>
  );
}

export default Login;

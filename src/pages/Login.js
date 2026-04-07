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
    <div className="auth-wrap">
      <div className="auth-card">
        <h1>Welcome back</h1>
        <p className="auth-subtitle">Sign in to your mise account</p>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Email
            <input type="email" name="email" value={form.email} onChange={handleChange} placeholder="you@example.com" required />
          </label>
          <label>
            Password
            <input type="password" name="password" value={form.password} onChange={handleChange} placeholder="••••••••" required />
          </label>
          <button type="submit">Sign in</button>
        </form>
        {error && <p className="auth-error">{error}</p>}
        <p className="auth-footer">
          No account? <Link to="/register">Create one</Link>
        </p>
      </div>
    </div>
  );
}

export default Login;

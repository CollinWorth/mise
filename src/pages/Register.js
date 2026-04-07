import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { apiFetch } from '../api';
import './css/Login_Register.css';

function Register({ onRegister }) {
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    try {
      const response = await apiFetch('/users/', {
        method: 'POST',
        body: JSON.stringify(form),
      });
      if (response.ok) {
        setSuccess('Account created! You can now sign in.');
        if (onRegister) onRegister();
      } else {
        const data = await response.json();
        if (Array.isArray(data.detail)) {
          setError(data.detail.map((e) => e.msg).join(', '));
        } else {
          setError(data.detail || 'Registration failed. Email may already be in use.');
        }
      }
    } catch (err) {
      setError('Registration failed. Please try again.');
    }
  };

  return (
    <div className="auth-wrap">
      <div className="auth-card">
        <h1>Create account</h1>
        <p className="auth-subtitle">Start building your recipe collection</p>
        <form className="auth-form" onSubmit={handleSubmit}>
          <label>
            Name
            <input type="text" name="name" value={form.name} onChange={handleChange} placeholder="Your name" required />
          </label>
          <label>
            Email
            <input type="email" name="email" value={form.email} onChange={handleChange} placeholder="you@example.com" required />
          </label>
          <label>
            Password
            <input type="password" name="password" value={form.password} onChange={handleChange} placeholder="••••••••" required />
          </label>
          <button type="submit">Create account</button>
        </form>
        {error && <p className="auth-error">{error}</p>}
        {success && <p className="auth-success">{success}</p>}
        <p className="auth-footer">
          Already have an account? <Link to="/login">Sign in</Link>
        </p>
      </div>
    </div>
  );
}

export default Register;

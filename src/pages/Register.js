import React, { useState } from 'react';
import './css/Login_Register.css';

function Register({ onRegister }) {
  const [form, setForm] = useState({ email: '', password: '', name: '' });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    try {
      const response = await fetch('http://localhost:8000/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: form.name,
          email: form.email,
          password: form.password,
        }),
      });
      if (response.ok) {
        setSuccess('Registration successful! You can now log in.');
        if (onRegister) onRegister();
      } else {
        const data = await response.json();
        if (Array.isArray(data.detail)) {
          setError(data.detail.map(err => err.msg).join(', '));
        } else if (typeof data.detail === 'object') {
          setError(JSON.stringify(data.detail));
        } else {
          setError(data.detail || 'Registration failed. Email may already be in use.');
        }
      }
    } catch (err) {
      setError('Registration failed. Please try again.');
    }
  };

  return (
    <div className="container" style={{ maxWidth: 400, margin: '48px auto' }}>
      <h1>Register</h1>
      <form className="login-register-form" onSubmit={handleSubmit}>
        <label>
          Name:
          <input
            type="text"
            name="name"
            value={form.name}
            onChange={handleChange}
            required
          />
        </label>
        <label>
          Email:
          <input
            type="email"
            name="email"
            value={form.email}
            onChange={handleChange}
            required
          />
        </label>
        <label>
          Password:
          <input
            type="password"
            name="password"
            value={form.password}
            onChange={handleChange}
            required
          />
        </label>
        <button type="submit">Register</button>
      </form>
      {error && <div className="login-register-message error">{error}</div>}
      {success && <div className="login-register-message success">{success}</div>}
    </div>
  );
}

export default Register;
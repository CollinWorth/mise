import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './css/Login_Register.css';

function Login({ onLogin }) {
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const response = await fetch('http://localhost:8000/users/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (response.ok) {
        const user = await response.json();
        if (onLogin) onLogin(user);
        navigate('/'); // Redirect to home
      } else {
        const data = await response.json();
        setError(data.detail || 'Invalid email or password');
      }
    } catch (err) {
      setError('Login failed. Please try again.');
    }
  };

  return (
    <div className="container" style={{ maxWidth: 400, margin: '48px auto' }}>
      <h1>Login</h1>
      <form className="login-register-form" onSubmit={handleSubmit}>
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
        <button type="submit">Login</button>
      </form>
      {error && <div className="login-register-message error">{error}</div>}
    </div>
  );
}

export default Login;
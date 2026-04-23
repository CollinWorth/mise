import React from 'react';
import { useNavigate } from 'react-router-dom';

export default function NotFoundPage() {
  const navigate = useNavigate();
  return (
    <div className="page" style={{ textAlign: 'center', paddingTop: '6rem' }}>
      <p style={{ fontSize: '4rem', marginBottom: '1rem' }}>404</p>
      <h1 style={{ marginBottom: '0.5rem' }}>Page not found</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
        That page doesn't exist or was moved.
      </p>
      <button className="btn-primary" onClick={() => navigate('/')}>Go home</button>
    </div>
  );
}

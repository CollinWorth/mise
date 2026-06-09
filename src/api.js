const API = process.env.REACT_APP_API_URL || 'http://localhost:8000';

export function imgUrl(url) {
  if (!url) return url;
  const m = url.match(/\/(images|uploads)\/[^?#\s]+/);
  if (m) return `${API}${m[0]}`;
  return url;
}

export function getToken() {
  return localStorage.getItem('mise_token');
}

export function getStoredUser() {
  const u = localStorage.getItem('mise_user');
  return u ? JSON.parse(u) : null;
}

export function setSession(token, user) {
  localStorage.setItem('mise_token', token);
  localStorage.setItem('mise_user', JSON.stringify(user));
}

export function clearSession() {
  localStorage.removeItem('mise_token');
  localStorage.removeItem('mise_user');
}

export async function apiFetch(path, options = {}) {
  const token = getToken();
  const headers = { 'Content-Type': 'application/json', ...options.headers };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  return fetch(`${API}${path}`, { ...options, headers });
}

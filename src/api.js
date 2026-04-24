const API = process.env.REACT_APP_API_URL || 'http://localhost:8000';

export function imgUrl(url) {
  if (!url) return url;
  // Only rewrite URLs our backend stored with a localhost base, or bare /uploads/ paths.
  // Leave external URLs (CDNs, WordPress, etc.) untouched even if they contain "/uploads/".
  if (/^https?:\/\/localhost(:\d+)?\/uploads\//.test(url)) {
    return `${API}${url.substring(url.indexOf('/uploads/'))}`;
  }
  if (url.startsWith('/uploads/')) {
    return `${API}${url}`;
  }
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

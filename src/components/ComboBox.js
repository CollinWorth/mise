import React, { useState, useRef, useEffect } from 'react';
import './css/ComboBox.css';

export default function ComboBox({ value = '', onChange, suggestions = [], placeholder = '', multi = false }) {
  const [input, setInput] = useState('');
  const [open, setOpen] = useState(false);
  const wrapRef = useRef(null);
  const inputRef = useRef(null);

  const values = multi
    ? (value ? value.split(',').map(t => t.trim()).filter(Boolean) : [])
    : [];

  const filtered = suggestions.filter(s => {
    const q = (multi ? input : value).toLowerCase();
    if (!q) return true;
    return s.toLowerCase().includes(q);
  }).filter(s =>
    multi ? !values.map(v => v.toLowerCase()).includes(s.toLowerCase()) : true
  ).slice(0, 12);

  useEffect(() => {
    const handler = e => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  const selectSingle = s => {
    onChange(s);
    setOpen(false);
    inputRef.current?.blur();
  };

  const selectMulti = s => {
    const t = s.trim();
    if (!t || values.map(v => v.toLowerCase()).includes(t.toLowerCase())) return;
    onChange([...values, t].join(', '));
    setInput('');
    inputRef.current?.focus();
  };

  const removeTag = tag => {
    onChange(values.filter(v => v !== tag).join(', '));
  };

  if (multi) {
    return (
      <div className="cb-wrap" ref={wrapRef}>
        <div className="cb-pills" onClick={() => inputRef.current?.focus()}>
          {values.map(v => (
            <span key={v} className="cb-pill">
              {v}
              <button type="button" className="cb-pill-remove" onClick={e => { e.stopPropagation(); removeTag(v); }}>×</button>
            </span>
          ))}
          <input
            ref={inputRef}
            className="cb-text-input"
            value={input}
            placeholder={values.length ? 'Add more…' : placeholder}
            onChange={e => { setInput(e.target.value); setOpen(true); }}
            onFocus={() => setOpen(true)}
            onKeyDown={e => {
              if ((e.key === 'Enter' || e.key === ',') && input.trim()) {
                e.preventDefault();
                selectMulti(input.trim());
              }
              if (e.key === 'Backspace' && !input && values.length) {
                removeTag(values[values.length - 1]);
              }
              if (e.key === 'Escape') setOpen(false);
            }}
          />
        </div>
        {open && filtered.length > 0 && (
          <ul className="cb-dropdown">
            {filtered.map(s => (
              <li key={s} className="cb-option" onMouseDown={e => { e.preventDefault(); selectMulti(s); }}>
                {s}
              </li>
            ))}
          </ul>
        )}
      </div>
    );
  }

  return (
    <div className="cb-wrap" ref={wrapRef}>
      <input
        ref={inputRef}
        className="cb-single-input"
        value={value}
        placeholder={placeholder}
        onChange={e => { onChange(e.target.value); setOpen(true); }}
        onFocus={() => setOpen(true)}
        onKeyDown={e => { if (e.key === 'Escape') setOpen(false); }}
      />
      {open && filtered.length > 0 && (
        <ul className="cb-dropdown">
          {filtered.map(s => (
            <li key={s} className="cb-option" onMouseDown={e => { e.preventDefault(); selectSingle(s); }}>
              {s}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

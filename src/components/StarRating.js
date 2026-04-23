import React, { useState } from 'react';
import './css/StarRating.css';

export default function StarRating({ rating = 0, onChange, size = 'md', showCount = false, count = 0 }) {
  const [hovered, setHovered] = useState(0);
  const interactive = !!onChange;
  const display = hovered || rating;

  return (
    <div className={`star-rating star-rating--${size}${interactive ? ' star-rating--interactive' : ''}`}>
      {[1, 2, 3].map(n =>
        interactive ? (
          <button
            key={n}
            type="button"
            className={`star${display >= n ? ' star--filled' : ' star--empty'}`}
            onMouseEnter={() => setHovered(n)}
            onMouseLeave={() => setHovered(0)}
            onClick={() => onChange(rating === n ? 0 : n)}
            aria-label={`Rate ${n} star${n !== 1 ? 's' : ''}`}
          >
            {display >= n ? '★' : '☆'}
          </button>
        ) : (
          <span key={n} className={`star${Math.round(display) >= n ? ' star--filled' : ' star--empty'}`}>
            {Math.round(display) >= n ? '★' : '☆'}
          </span>
        )
      )}
      {showCount && count > 0 && <span className="star-count">({count})</span>}
    </div>
  );
}

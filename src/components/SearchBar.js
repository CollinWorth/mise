import React from 'react';

function SearchBar({ onSearch }) {
  return (
    <input
      type="search"
      placeholder="Search recipes..."
      onChange={(e) => onSearch(e.target.value)}
      style={{ width: '100%' }}
    />
  );
}

export default SearchBar;

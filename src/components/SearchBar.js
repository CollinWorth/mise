import React from 'react';
import './css/SearchBar.css';

function SearchBar({ onSearch }) {
  const handleInputChange = (e) => {
    onSearch(e.target.value);
  };

  return (
    <div className="search-bar">
      <input
        type="text"
        placeholder="Search recipes..."
        onChange={handleInputChange}
        className="search-input"
      />
    </div>
    );
}
export default SearchBar;
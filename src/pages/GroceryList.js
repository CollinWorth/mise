import React, { useState, useEffect } from 'react';
import './css/GroceryList.css';

function GroceryList({ user }) {
  const [groceryLists, setGroceryLists] = useState([]);
  const [newItem, setNewItem] = useState('');
  const [newItemQuantity, setNewItemQuantity] = useState('');
  const [selectedListId, setSelectedListId] = useState(null);

  useEffect(() => {
    if (user) fetchGroceryLists();
  }, [user]);

  const fetchGroceryLists = async () => {
    try {
      const res = await fetch(`http://localhost:8000/groceryList/userID/${user.id || user._id}`);
      if (res.ok) {
        const data = await res.json();
        setGroceryLists(data);
        if (data.length > 0) setSelectedListId(data[0]._id);
      } else {
        console.error('Failed to fetch lists:', res.statusText);
      }
    } catch (err) {
      console.error('Fetch error:', err);
    }
  };

  const addItem = async () => {
    if (!newItem.trim() || !newItemQuantity.trim() || !selectedListId) return;
    try {
      const res = await fetch(`http://localhost:8000/groceryList/${selectedListId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: newItem.trim(),
          quantity: newItemQuantity.trim(),
          category: 'Other',
          checked: false
        })
      });
      if (res.ok) {
        fetchGroceryLists();
        setNewItem('');
        setNewItemQuantity('');
      } else {
        console.error('Failed to add item:', res.statusText);
      }
    } catch (err) {
      console.error('Add error:', err);
    }
  };

  const removeItem = async (itemName) => {
    try {
      const res = await fetch(`http://localhost:8000/groceryList/${selectedListId}/${itemName}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        fetchGroceryLists();
      } else {
        console.error('Failed to remove item:', res.statusText);
      }
    } catch (err) {
      console.error('Remove error:', err);
    }
  };

  return (
    <div className="grocery-page-wrapper">
      {/* Sticky Header */}
      <div className="grocery-header">
      </div>

      {/* Main Grid Layout */}
      <div className="grocery-layout">
        {/* Left Sidebar */}
        <aside className="grocery-sidebar-left">
          <h3>Your Lists</h3>
          <ul>
            {groceryLists.map((list) => (
              <li
                key={list._id}
                onClick={() => setSelectedListId(list._id)}
                style={{
                  fontWeight: selectedListId === list._id ? 'bold' : 'normal',
                  cursor: 'pointer',
                }}
              >
                {list.name}
              </li>
            ))}
          </ul>
        </aside>

        {/* Main Section */}
        <main className="grocery">
          <h1>{groceryLists.find((list) => list._id === selectedListId)?.name || 'Select a List'}</h1>
          <p>Add items to your grocery list:</p>

          <div className="add-item">
            <input
              type="text"
              placeholder="Item name"
              value={newItem}
              onChange={(e) => setNewItem(e.target.value)}
            />
            <input
              type="text"
              placeholder="Quantity"
              value={newItemQuantity}
              onChange={(e) => setNewItemQuantity(e.target.value)}
            />
            <button onClick={addItem}>Add</button>
          </div>

          <div className="grocery-list">
            {selectedListId &&
              groceryLists
                .filter((list) => list._id === selectedListId)
                .map((list) => (
                  <div key={list._id} className="grocery-card">
                    {list.items.length > 0 ? (
                      list.items.map((item, idx) => (
                        <div key={idx} className="grocery-details-row">
                          <span>
                            {item.name} ({item.quantity})
                          </span>
                          <button
                            className="remove-item"
                            onClick={() => removeItem(item.name)}
                          >
                            Remove
                          </button>
                        </div>
                      ))
                    ) : (
                      <p>No items yet.</p>
                    )}
                  </div>
                ))}
          </div>
        </main>

      </div>
    </div>
  );
}

export default GroceryList;

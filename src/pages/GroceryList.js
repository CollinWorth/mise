import React, { useState, useEffect, useRef } from 'react';
import { apiFetch } from '../api';
import './css/GroceryList.css';

// ── Store sections in aisle order ────────────────────────────────────
const SECTIONS = [
  { key: 'produce',    label: 'Produce',          icon: '🥦', keywords: ['apple','apples','banana','bananas','orange','oranges','lemon','lemons','lime','limes','tomato','tomatoes','lettuce','spinach','kale','arugula','onion','onions','shallot','shallots','garlic','carrot','carrots','celery','cucumber','cucumbers','zucchini','pepper','peppers','potato','potatoes','sweet potato','broccoli','cauliflower','mushroom','mushrooms','avocado','avocados','corn','peas','green beans','ginger','cilantro','parsley','basil','thyme','rosemary','mint','dill','chives','scallion','scallions','leek','leeks','fennel','radish','beet','beets','squash','pumpkin','eggplant','asparagus','artichoke','cabbage','bok choy','brussels sprouts','mango','pineapple','strawberry','strawberries','blueberry','blueberries','raspberry','raspberries','blackberry','blackberries','grapes','cherry','cherries','peach','peaches','plum','plums','pear','pears','watermelon','cantaloupe','melon','fig','figs','dates','pomegranate','jalapeño','jalapeno','habanero','serrano','herbs'] },
  { key: 'meat',       label: 'Meat & Seafood',   icon: '🥩', keywords: ['chicken','beef','pork','lamb','turkey','duck','veal','bison','bacon','sausage','ham','salami','prosciutto','pancetta','chorizo','pepperoni','salmon','tuna','shrimp','cod','tilapia','halibut','crab','lobster','scallop','scallops','anchovy','anchovies','sardines','mahi','sea bass','snapper','trout','clam','clams','mussel','mussels','oyster','oysters','steak','ribs','brisket','tenderloin','ground beef','ground turkey','ground pork','chicken breast','chicken thigh','chicken thighs','drumstick','wings','pork chop','pork belly','hot dog','hot dogs','deli meat'] },
  { key: 'dairy',      label: 'Dairy & Eggs',     icon: '🥛', keywords: ['milk','whole milk','skim milk','oat milk','almond milk','soy milk','cream','heavy cream','half and half','whipping cream','butter','unsalted butter','salted butter','ghee','cheese','parmesan','mozzarella','cheddar','feta','ricotta','brie','gouda','gruyere','swiss','provolone','cream cheese','cottage cheese','yogurt','greek yogurt','sour cream','crème fraîche','egg','eggs','kefir','buttermilk','whipped cream'] },
  { key: 'deli',       label: 'Deli',             icon: '🫕', keywords: ['deli','rotisserie','hummus','tzatziki','guacamole','prepared','cooked chicken','smoked salmon','lox','pastrami','corned beef','roast beef'] },
  { key: 'bakery',     label: 'Bakery & Bread',   icon: '🍞', keywords: ['bread','sourdough','baguette','roll','rolls','bagel','bagels','pita','tortilla','tortillas','naan','croissant','croissants','muffin','muffins','english muffin','brioche','ciabatta','focaccia','rye','whole wheat bread','white bread','hamburger bun','hot dog bun','flatbread','lavash','matzo','cake','pie crust','pastry','danish','scone','biscuit','biscuits'] },
  { key: 'frozen',     label: 'Frozen',           icon: '🧊', keywords: ['frozen','ice cream','gelato','sorbet','frozen peas','frozen corn','frozen berries','frozen spinach','edamame','frozen pizza','frozen burrito','frozen waffle','waffles','tater tots','french fries','ice','frozen fruit','frozen vegetables'] },
  { key: 'canned',     label: 'Canned & Jarred',  icon: '🥫', keywords: ['canned','tomato paste','crushed tomatoes','diced tomatoes','whole tomatoes','tomato sauce','tomato puree','coconut milk','chicken broth','beef broth','vegetable broth','stock','chicken stock','beef stock','beans','black beans','kidney beans','chickpeas','garbanzo','lentils','pinto beans','white beans','cannellini','corn canned','tuna canned','sardines canned','soup','olives','artichoke hearts','roasted peppers','capers','pumpkin puree','evaporated milk','condensed milk','pickles','pickle','jam','jelly','preserve','salsa','enchilada sauce','coconut cream','curry paste','miso paste'] },
  { key: 'dry_goods',  label: 'Dry Goods & Pasta', icon: '🌾', keywords: ['pasta','spaghetti','penne','rigatoni','fettuccine','linguine','lasagna','orzo','farfalle','fusilli','rice','white rice','brown rice','jasmine rice','basmati rice','arborio','quinoa','couscous','farro','barley','bulgur','oats','rolled oats','polenta','cornmeal','flour','bread flour','all-purpose flour','whole wheat flour','almond flour','breadcrumbs','panko','noodles','ramen noodles','udon','soba','glass noodles','rice noodles','cereal','granola','crackers','tortilla chips','chips','popcorn','nuts','almonds','walnuts','pecans','peanuts','cashews','pistachios','pine nuts','sunflower seeds','pumpkin seeds','sesame seeds','chia seeds','flaxseed','dried fruit','raisins','cranberries dried','apricots dried','prunes','lentils dried','split peas'] },
  { key: 'breakfast',  label: 'Breakfast',        icon: '🥞', keywords: ['pancake mix','waffle mix','maple syrup','syrup','honey','peanut butter','almond butter','nutella','jam','jelly','orange juice','coffee','espresso','tea','oatmeal','granola bar','protein bar'] },
  { key: 'condiments', label: 'Condiments & Sauces', icon: '🧴', keywords: ['ketchup','mustard','mayo','mayonnaise','hot sauce','sriracha','tabasco','worcestershire','soy sauce','tamari','fish sauce','oyster sauce','hoisin','teriyaki','bbq sauce','buffalo sauce','ranch','caesar','italian dressing','balsamic','vinegar','apple cider vinegar','red wine vinegar','white wine vinegar','rice vinegar','olive oil','vegetable oil','canola oil','coconut oil','sesame oil','truffle oil','avocado oil','cooking spray','lemon juice','lime juice'] },
  { key: 'spices',     label: 'Spices & Baking',  icon: '🧂', keywords: ['salt','kosher salt','sea salt','pepper','black pepper','cumin','paprika','smoked paprika','turmeric','cinnamon','chili powder','cayenne','oregano','thyme dried','rosemary dried','bay leaf','bay leaves','nutmeg','cloves','cardamom','coriander','fennel seeds','mustard seeds','curry powder','garam masala','za\'atar','everything bagel','red pepper flakes','garlic powder','onion powder','italian seasoning','herbs de provence','sugar','brown sugar','powdered sugar','honey','maple syrup baking','vanilla','vanilla extract','baking powder','baking soda','yeast','instant yeast','cornstarch','arrowroot','gelatin','cocoa powder','chocolate chips','dark chocolate','white chocolate','food coloring'] },
  { key: 'beverages',  label: 'Beverages',        icon: '🥤', keywords: ['water','sparkling water','soda','cola','juice','orange juice','apple juice','wine','red wine','white wine','rose','champagne','beer','lager','ale','ipa','spirits','vodka','gin','whiskey','rum','tequila','kombucha','lemonade','energy drink','sports drink','coconut water'] },
  { key: 'household',  label: 'Household',        icon: '🧹', keywords: ['paper towel','toilet paper','dish soap','laundry','detergent','sponge','trash bag','zip lock','plastic wrap','aluminum foil','parchment','wax paper','cleaning','bleach','soap','shampoo','conditioner','lotion','toothpaste','deodorant','razors'] },
  { key: 'other',      label: 'Other',            icon: '🛒', keywords: [] },
];

const SECTION_MAP = Object.fromEntries(SECTIONS.map(s => [s.key, s]));

function categorize(name) {
  const lower = name.toLowerCase();
  for (const section of SECTIONS) {
    if (section.key === 'other') continue;
    if (section.keywords.some(k => lower.includes(k))) return section.key;
  }
  return 'other';
}

// ── Smart input parser ────────────────────────────────────────────────
// Handles: "2 cups flour", "350g bread flour", "2tbsp olive oil", "milk"
const UNITS_RE = /^(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|oz|ounce|ounces|lb|lbs|pound|pounds|g|gram|grams|kg|ml|milliliter|liter|liters|l|clove|cloves|can|cans|bunch|pinch|dash|slice|slices|piece|pieces|sprig|sprigs|stalk|stalks|sheet|strip|strips|pkg|package|packages)\b/i;

function parseInput(raw) {
  const s = raw.trim();
  // Match: optional number (fraction/decimal/integer) possibly glued to a unit
  const m = s.match(/^([\d\s\/½⅓¼¾⅔⅛⅜⅝⅞]+(?:\.\d+)?)\s*/);
  if (!m) return { name: s, quantity: '', unit: '' };

  const quantity = m[1].trim();
  const rest = s.slice(m[0].length);

  // Check if unit is attached (e.g. "350g") or space-separated
  const unitMatch = rest.match(UNITS_RE);
  if (unitMatch) {
    const unit = unitMatch[0];
    const name = rest.slice(unit.length).trim();
    return { name: name || rest, quantity, unit };
  }
  return { name: rest, quantity, unit: '' };
}

// ── Quick-add staples ────────────────────────────────────────────────
const QUICK_ITEMS = [
  'Milk', 'Eggs', 'Butter', 'Bread', 'Cheese', 'Yogurt',
  'Onion', 'Garlic', 'Tomatoes', 'Lemons', 'Avocados',
  'Chicken', 'Olive oil', 'Salt', 'Pasta', 'Rice',
];

// ── Week helpers (for meal plan panel) ───────────────────────────────
const MONTH_NAMES = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
function startOfWeek(date) {
  const d = new Date(date);
  d.setDate(d.getDate() - d.getDay());
  d.setHours(0,0,0,0);
  return d;
}
function addDays(date, n) { const d = new Date(date); d.setDate(d.getDate() + n); return d; }
function formatDate(date) { return new Date(date).toISOString().split('T')[0]; }

export default function GroceryList({ user }) {
  const [list, setList] = useState(null);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(true);
  const [adding, setAdding] = useState(false);
  const [showMealPlan, setShowMealPlan] = useState(false);
  const [mpWeekStart, setMpWeekStart] = useState(() => startOfWeek(new Date()));
  const [mpLoading, setMpLoading] = useState(false);
  const [mpToast, setMpToast] = useState('');
  const inputRef = useRef(null);

  useEffect(() => { if (user) init(); }, [user]);

  const init = async () => {
    setLoading(true);
    try {
      const res = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
      if (res.ok) {
        const data = await res.json();
        if (data.length > 0) {
          setList(data[0]);
        } else {
          const cr = await apiFetch('/groceryList/', {
            method: 'POST',
            body: JSON.stringify({ name: 'My List', user_id: user.id || user._id, items: [] }),
          });
          if (cr.ok) {
            const res2 = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
            if (res2.ok) { const d2 = await res2.json(); setList(d2[0] || null); }
          }
        }
      }
    } catch (e) {}
    setLoading(false);
  };

  const addItem = async (itemName, itemQty = '', itemUnit = '') => {
    const name = itemName || parseInput(input).name;
    const quantity = itemQty || parseInput(input).quantity;
    const unit = itemUnit || parseInput(input).unit;
    if (!name || !list || adding) return;
    setAdding(true);
    try {
      const res = await apiFetch(`/groceryList/${list._id}`, {
        method: 'PUT',
        body: JSON.stringify({ name, quantity, unit, category: categorize(name), checked: false }),
      });
      if (res.ok) {
        setList(l => ({
          ...l,
          items: [...(l.items || []), { name, quantity, unit, category: categorize(name), checked: false }],
        }));
        if (!itemName) { setInput(''); inputRef.current?.focus(); }
      }
    } catch (e) {}
    setAdding(false);
  };

  const quickAdd = (name) => {
    if (!list) return;
    const alreadyAdded = (list.items || []).some(i => i.name.toLowerCase() === name.toLowerCase());
    if (!alreadyAdded) addItem(name);
  };

  const toggleItem = async (itemName, currentChecked) => {
    setList(l => ({ ...l, items: l.items.map(i => i.name === itemName ? { ...i, checked: !currentChecked } : i) }));
    try {
      await apiFetch(`/groceryList/${list._id}/${encodeURIComponent(itemName)}/check`, { method: 'PATCH' });
    } catch (e) {
      setList(l => ({ ...l, items: l.items.map(i => i.name === itemName ? { ...i, checked: currentChecked } : i) }));
    }
  };

  const removeItem = async (itemName) => {
    setList(l => ({ ...l, items: l.items.filter(i => i.name !== itemName) }));
    try { await apiFetch(`/groceryList/${list._id}/${encodeURIComponent(itemName)}`, { method: 'DELETE' }); } catch (e) {}
  };

  const clearChecked = async () => {
    const checked = (list?.items || []).filter(i => i.checked);
    setList(l => ({ ...l, items: l.items.filter(i => !i.checked) }));
    for (const item of checked) {
      try { await apiFetch(`/groceryList/${list._id}/${encodeURIComponent(item.name)}`, { method: 'DELETE' }); } catch (e) {}
    }
  };

  const generateFromMealPlan = async () => {
    setMpLoading(true);
    const start = formatDate(mpWeekStart);
    const end = formatDate(addDays(mpWeekStart, 6));
    try {
      const res = await apiFetch('/groceryList/from-meal-plan', {
        method: 'POST',
        body: JSON.stringify({ user_id: user.id || user._id, start_date: start, end_date: end }),
      });
      if (res.ok) {
        const data = await res.json();
        setMpToast(data.added === 0
          ? (data.message || 'No new ingredients to add.')
          : `Added ${data.added} ingredient${data.added !== 1 ? 's' : ''}${data.skipped ? ` · ${data.skipped} already on list` : ''}`
        );
        if (data.added > 0) {
          const r2 = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
          if (r2.ok) { const d2 = await r2.json(); if (d2.length) setList(d2[0]); }
        }
      }
    } catch (e) { setMpToast('Something went wrong.'); }
    setMpLoading(false);
    setTimeout(() => setMpToast(''), 4000);
  };

  const items = list?.items || [];
  const checkedCount = items.filter(i => i.checked).length;

  // Group unchecked by section key, maintain store aisle order
  const grouped = {};
  for (const item of items.filter(i => !i.checked)) {
    const key = item.category || categorize(item.name);
    if (!grouped[key]) grouped[key] = [];
    grouped[key].push(item);
  }
  const sortedGroups = SECTIONS.map(s => s.key).filter(k => grouped[k]?.length > 0);

  const addedNames = new Set((list?.items || []).map(i => i.name.toLowerCase()));

  if (!user) return (
    <div className="grocery-splash">
      <div className="grocery-splash-inner">
        <h1>Your grocery list,<br />always with you.</h1>
        <p>Sign in to start building your list.</p>
      </div>
    </div>
  );

  return (
    <div className="grocery-page">
      <div className="grocery-header">
        <div className="grocery-header-left">
          <h1>Grocery List</h1>
          {!loading && items.length > 0 && (
            <span className="grocery-progress">{checkedCount}/{items.length}</span>
          )}
        </div>
        {checkedCount > 0 && (
          <button className="btn-ghost grocery-clear-btn" onClick={clearChecked}>
            Clear {checkedCount} checked
          </button>
        )}
      </div>

      {/* Meal plan */}
      <div className="mp-bar">
        <button className={`mp-toggle${showMealPlan ? ' mp-toggle--open' : ''}`} onClick={() => setShowMealPlan(v => !v)}>
          <span>📅</span> From meal plan <span className="mp-toggle-arrow">{showMealPlan ? '▲' : '▼'}</span>
        </button>
        {mpToast && <span className="mp-toast">{mpToast}</span>}
      </div>
      {showMealPlan && (() => {
        const end = addDays(mpWeekStart, 6);
        const sm = MONTH_NAMES[mpWeekStart.getMonth()];
        const em = MONTH_NAMES[end.getMonth()];
        return (
          <div className="mp-panel">
            <div className="mp-week-nav">
              <button className="mp-nav-btn" onClick={() => setMpWeekStart(d => addDays(d, -7))}>←</button>
              <span className="mp-week-label">{sm} {mpWeekStart.getDate()} – {sm !== em ? em + ' ' : ''}{end.getDate()}</span>
              <button className="mp-nav-btn" onClick={() => setMpWeekStart(d => addDays(d, 7))}>→</button>
            </div>
            <p className="mp-hint">Add ingredients from all recipes planned this week.</p>
            <button className="btn-primary mp-generate-btn" onClick={generateFromMealPlan} disabled={mpLoading}>
              {mpLoading ? 'Adding…' : 'Add ingredients to list'}
            </button>
          </div>
        );
      })()}

      {/* Add bar */}
      <div className="grocery-add-bar">
        <input
          ref={inputRef}
          type="text"
          className="grocery-add-input"
          placeholder='Add an item — "350g flour", "2 tbsp oil", or just "milk"'
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && addItem()}
          disabled={loading}
        />
        <button className="btn-primary" onClick={() => addItem()} disabled={adding || !input.trim() || loading}>
          Add
        </button>
      </div>

      {/* Quick-add chips */}
      <div className="quick-add-row">
        {QUICK_ITEMS.filter(n => !addedNames.has(n.toLowerCase())).slice(0, 10).map(name => (
          <button key={name} className="quick-add-chip" onClick={() => quickAdd(name)}>
            + {name}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="grocery-loading">
          {Array.from({ length: 5 }).map((_, i) => <div key={i} className="grocery-skeleton" />)}
        </div>
      ) : items.length === 0 ? (
        <div className="grocery-empty">
          <p className="grocery-empty-icon">🛒</p>
          <h3>Your list is empty</h3>
          <p>Add items above or tap a quick-add chip to get started.</p>
        </div>
      ) : (
        <div className="grocery-content">
          {sortedGroups.map(key => {
            const section = SECTION_MAP[key];
            return (
              <div key={key} className="grocery-category">
                <div className="grocery-category-header">
                  <span className="grocery-category-icon">{section.icon}</span>
                  <span className="grocery-category-label">{section.label}</span>
                  <span className="grocery-category-count">{grouped[key].length}</span>
                </div>
                <div className="grocery-category-items">
                  {grouped[key].map((item, idx) => (
                    <GroceryItem key={idx} item={item}
                      onToggle={() => toggleItem(item.name, item.checked)}
                      onRemove={() => removeItem(item.name)}
                    />
                  ))}
                </div>
              </div>
            );
          })}
          {checkedCount > 0 && (
            <div className="grocery-category grocery-category--checked">
              <div className="grocery-category-header">
                <span className="grocery-category-icon">✓</span>
                <span className="grocery-category-label">In cart</span>
                <span className="grocery-category-count">{checkedCount}</span>
              </div>
              <div className="grocery-category-items">
                {items.filter(i => i.checked).map((item, idx) => (
                  <GroceryItem key={idx} item={item}
                    onToggle={() => toggleItem(item.name, item.checked)}
                    onRemove={() => removeItem(item.name)}
                  />
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function GroceryItem({ item, onToggle, onRemove }) {
  const qtyLabel = [item.quantity, item.unit].filter(Boolean).join(' ');
  return (
    <div className={`grocery-item${item.checked ? ' grocery-item--checked' : ''}`}>
      <button className="grocery-checkbox" onClick={onToggle} aria-label="Toggle">
        <span className="grocery-checkbox-inner">{item.checked ? '✓' : ''}</span>
      </button>
      <span className="grocery-item-name">{item.name}</span>
      {qtyLabel && <span className="grocery-item-qty">{qtyLabel}</span>}
      <button className="grocery-remove" onClick={onRemove} aria-label="Remove">✕</button>
    </div>
  );
}

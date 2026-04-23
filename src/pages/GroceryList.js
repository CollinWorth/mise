import React, { useState, useEffect, useRef, useCallback } from 'react';
import { apiFetch } from '../api';
import { useToast } from '../contexts/ToastContext';
import './css/GroceryList.css';

// ── Pantry (localStorage) ─────────────────────────────────────────────────────
const PANTRY_KEY = 'mise_pantry';
const DEFAULT_PANTRY = [
  'salt','pepper','black pepper','olive oil','vegetable oil','canola oil',
  'sugar','brown sugar','flour','all purpose flour','bread flour',
  'baking powder','baking soda','butter','water','garlic','onion',
  'vanilla extract','cooking spray',
];
function pantryGet() {
  try {
    const raw = localStorage.getItem(PANTRY_KEY);
    return raw ? JSON.parse(raw) : [...DEFAULT_PANTRY];
  } catch { return [...DEFAULT_PANTRY]; }
}
function pantrySave(items) {
  try { localStorage.setItem(PANTRY_KEY, JSON.stringify(items)); } catch {}
}
// Strip leading prep adjectives so "fresh garlic" → "garlic", "unsalted butter" → "butter"
const PREP_PREFIX_RE = /^(fresh|dried|dry|ground|minced|chopped|diced|sliced|crushed|whole|raw|cooked|roasted|toasted|peeled|grated|shredded|cubed|halved|unsalted|salted|organic|extra[\s-]virgin|light|dark|pure|large|medium|small|ripe|firm|hot|mild|sweet|frozen|canned|low[\s-]sodium|reduced[\s-]fat)\s+/i;

function pantryMatches(name, pantry) {
  const lower = name.toLowerCase().trim();
  const stripped = lower.replace(PREP_PREFIX_RE, '').trim();
  return pantry.some(p => {
    // Exact match on the raw or adjective-stripped name, with optional trailing 's'
    return lower === p || stripped === p ||
      lower === p + 's' || stripped === p + 's' ||
      (p.endsWith('s') && (lower === p.slice(0, -1) || stripped === p.slice(0, -1)));
  });
}

// ── Fraction-aware quantity parser ────────────────────────────────────────────
function parseFraction(s) {
  if (!s) return 0;
  const str = String(s).trim()
    .replace(/½/g,'1/2').replace(/⅓/g,'1/3').replace(/¼/g,'1/4')
    .replace(/¾/g,'3/4').replace(/⅔/g,'2/3').replace(/⅛/g,'1/8')
    .replace(/⅜/g,'3/8').replace(/⅝/g,'5/8').replace(/⅞/g,'7/8');
  const mixed = str.match(/^(\d+)\s+(\d+)\/(\d+)$/);
  if (mixed) return +mixed[1] + +mixed[2] / +mixed[3];
  const frac = str.match(/^(\d+)\/(\d+)$/);
  if (frac) return +frac[1] / +frac[2];
  return parseFloat(str) || 0;
}

// ── Ingredient name normalizer (key for dedup, not display) ──────────────────
// Handles: "garlic, minced" → "garlic", "fresh garlic" → "garlic",
//          "onions" → "onion", "tomatoes" → "tomato", "eggs" → "egg"
function normalizeIngKey(name) {
  let s = (name || '').toLowerCase().trim();
  // Strip everything after a comma: "butter, softened" → "butter"
  s = s.replace(/\s*,.*$/, '').trim();
  // Strip leading prep adjectives: "fresh garlic" → "garlic"
  s = s.replace(PREP_PREFIX_RE, '').trim();
  // Plural normalization (most specific first)
  if (s.endsWith('ies') && s.length > 4) return s.slice(0, -3) + 'y'; // berries→berry
  if (s.endsWith('oes') && s.length > 4) return s.slice(0, -2);       // tomatoes→tomato (remove 'es')
  if (s.endsWith('s') && !s.endsWith('ss') && !s.endsWith('us') && s.length > 3) return s.slice(0, -1); // onions→onion
  return s;
}

// ── Unit normalizer (so "tbsp" and "tablespoon" are treated the same) ─────────
const UNIT_ALIASES = {
  tablespoon:'tbsp', tablespoons:'tbsp', tbs:'tbsp',
  teaspoon:'tsp', teaspoons:'tsp',
  ounce:'oz', ounces:'oz',
  pound:'lb', pounds:'lb', lbs:'lb',
  gram:'g', grams:'g',
  kilogram:'kg', kilograms:'kg',
  milliliter:'ml', milliliters:'ml',
  liter:'l', liters:'l',
  cup:'cup', cups:'cup',
  clove:'clove', cloves:'clove',
  can:'can', cans:'can',
  piece:'piece', pieces:'piece',
  slice:'slice', slices:'slice',
};
function normalizeUnit(u) {
  const lower = (u || '').toLowerCase().trim();
  return UNIT_ALIASES[lower] || lower;
}

// ── Ingredient merging ────────────────────────────────────────────────────────
function mergeIngredients(recipes) {
  // result keyed by normalized name; stores display name + running qty
  const result = {};
  for (const recipe of recipes) {
    const mult = recipe._count || 1;
    for (const ing of (recipe.ingredients || [])) {
      if (!(ing.name || '').trim()) continue;
      const key  = normalizeIngKey(ing.name);
      const qty  = parseFraction(ing.quantity) * mult;
      const unit = normalizeUnit(ing.unit);
      if (result[key]) {
        const ex = result[key];
        // Add quantities when units match
        if (ex.unit === unit) {
          const combined = parseFraction(ex.quantity) + qty;
          if (combined > 0) ex.quantity = fmtQty(combined);
        } else if (!ex.unit && unit) {
          // Adopt unit if existing entry had none
          ex.unit = ing.unit;
          if (qty > 0) ex.quantity = fmtQty(parseFraction(ex.quantity) + qty);
        }
        // Keep the more descriptive display name (longer = more specific)
        if (ing.name.length > ex.name.length) ex.name = ing.name;
      } else {
        result[key] = {
          name: ing.name,
          quantity: qty > 0 ? fmtQty(qty) : (ing.quantity || ''),
          unit: ing.unit || '',
        };
      }
    }
  }
  return Object.values(result);
}
function fmtQty(n) {
  if (n === Math.trunc(n)) return String(Math.trunc(n));
  // Convert to common fractions for readability
  const fracs = [[1,4],[1,3],[1,2],[2,3],[3,4]];
  for (const [num, den] of fracs) {
    const whole = Math.trunc(n);
    const rem = n - whole;
    if (Math.abs(rem - num/den) < 0.05) return whole > 0 ? `${whole} ${num}/${den}` : `${num}/${den}`;
  }
  return String(Math.round(n * 100) / 100);
}

// ── Store sections in aisle order ────────────────────────────────────
const SECTIONS = [
  { key: 'produce',    label: 'Produce',             icon: '🥦', keywords: ['apple','banana','orange','lemon','lime','lettuce','spinach','kale','arugula','spring mix','onion','shallot','scallion','green onion','garlic clove','garlic cloves','carrot','celery','cucumber','zucchini','bell pepper','chile pepper','jalapeño','jalapeno','habanero','serrano','chili pepper','poblano','potato','sweet potato','yam','broccoli','cauliflower','mushroom','shiitake','cremini','portobello','avocado','corn','peas','green bean','green beans','ginger','cilantro','parsley','basil','thyme','rosemary','mint','dill','chives','leek','fennel','radish','beet','butternut squash','acorn squash','spaghetti squash','summer squash','pumpkin','eggplant','asparagus','artichoke','cabbage','bok choy','brussels sprout','mango','pineapple','strawberry','blueberry','raspberry','blackberry','grapes','cherry','peach','plum','pear','watermelon','cantaloupe','melon','honeydew','fig','dates','pomegranate','lemongrass','turmeric root','fresh herb','micro greens','endive','watercress','radicchio','snap peas','snow peas','sugar snap peas','butterhead','romaine','iceberg','turnip','parsnip','rutabaga'] },
  { key: 'meat',       label: 'Meat & Seafood',      icon: '🥩', keywords: ['chicken breast','chicken thigh','chicken thighs','chicken drumstick','chicken wing','whole chicken','ground chicken','ground beef','ground pork','ground turkey','ground lamb','chicken','beef','pork','lamb','turkey','duck','veal','bison','venison','bacon','pancetta','prosciutto','sausage','italian sausage','chorizo','andouille','bratwurst','pepperoni','salami','ham','lunchmeat','deli meat','steak','ribeye','sirloin','filet mignon','brisket','short rib','pork chop','pork loin','pork belly','pork shoulder','baby back ribs','spare ribs','tenderloin','salmon','tuna','shrimp','prawns','cod','tilapia','halibut','mahi','sea bass','snapper','trout','catfish','crab','lobster','scallop','anchovy','anchovies','sardine','clam','mussel','oyster','squid','octopus','langostino','imitation crab','surimi'] },
  { key: 'dairy',      label: 'Dairy & Eggs',        icon: '🥛', keywords: ['whole milk','skim milk','2% milk','oat milk','almond milk','soy milk','coconut milk beverage','heavy cream','heavy whipping cream','half and half','half & half','whipping cream','light cream','sour cream','crème fraîche','cream fraiche','buttermilk','milk','butter','ghee','clarified butter','parmesan','parmigiano','mozzarella','cheddar','feta','ricotta','brie','gouda','gruyere','gruyère','swiss cheese','provolone','cream cheese','cottage cheese','mascarpone','burrata','havarti','manchego','asiago','pecorino','monterey jack','colby','blue cheese','gorgonzola','bocconcini','queso fresco','queso','cheese','yogurt','greek yogurt','skyr','eggs','egg','kefir','whipped cream','dulce de leche'] },
  { key: 'deli',       label: 'Deli',                icon: '🫕', keywords: ['deli','rotisserie chicken','hummus','tzatziki','guacamole','smoked salmon','lox','nova lox','pastrami','corned beef','roast beef'] },
  { key: 'bakery',     label: 'Bakery & Bread',      icon: '🍞', keywords: ['sourdough','baguette','dinner roll','kaiser roll','bagel','pita','pita bread','flour tortilla','corn tortilla','tortilla','naan','croissant','english muffin','brioche','ciabatta','focaccia','rye bread','pumpernickel','whole wheat bread','white bread','hamburger bun','hot dog bun','slider bun','sub roll','hoagie roll','flatbread','lavash','matzo','bread','pie crust','pie shell','pastry dough','puff pastry','danish','scone','biscuit','cake layer','cornbread'] },
  { key: 'frozen',     label: 'Frozen',              icon: '🧊', keywords: ['frozen peas','frozen corn','frozen edamame','frozen spinach','frozen broccoli','frozen mixed vegetables','frozen berries','frozen mango','frozen fruit','frozen vegetables','edamame','ice cream','gelato','sorbet','frozen pizza','frozen waffle','tater tots','french fries','frozen','ice cubes'] },
  { key: 'canned',     label: 'Canned & Jarred',     icon: '🥫', keywords: ['tomato paste','crushed tomatoes','diced tomatoes','fire roasted tomatoes','whole peeled tomatoes','stewed tomatoes','tomato sauce','tomato puree','tomato soup','chicken broth','beef broth','vegetable broth','chicken stock','beef stock','vegetable stock','bone broth','stock cubes','bouillon','coconut milk','coconut cream','black beans','kidney beans','chickpeas','garbanzo beans','lentils','pinto beans','white beans','cannellini beans','navy beans','great northern beans','refried beans','baked beans','green lentils','red lentils','canned tuna','canned salmon','canned chicken','canned corn','canned green beans','canned artichoke','canned olives','artichoke hearts','roasted red peppers','capers','pumpkin puree','sweet potato puree','evaporated milk','sweetened condensed milk','condensed milk','pickles','dill pickles','bread and butter pickles','giardiniera','jam','jelly','fruit preserves','marmalade','salsa','enchilada sauce','green chile','chipotle in adobo','miso paste','curry paste','red curry paste','green curry paste','tahini','peanut butter','almond butter','nut butter','sun dried tomatoes','olive tapenade','harissa','gochujang','sambal','soup'] },
  { key: 'dry_goods',  label: 'Dry Goods & Pasta',   icon: '🌾', keywords: ['spaghetti','penne','rigatoni','fettuccine','linguine','lasagna noodles','lasagna','orzo','farfalle','fusilli','rotini','bucatini','tagliatelle','pappardelle','angel hair','ditalini','macaroni','egg noodles','pasta','white rice','brown rice','jasmine rice','basmati rice','arborio rice','sushi rice','long grain rice','short grain rice','rice','quinoa','couscous','farro','barley','bulgur','wheat berries','freekeh','rolled oats','steel cut oats','quick oats','oats','polenta','grits','cornmeal','all purpose flour','bread flour','whole wheat flour','self rising flour','cake flour','almond flour','oat flour','tapioca flour','coconut flour','flour','breadcrumbs','panko','ramen noodles','udon noodles','soba noodles','rice noodles','glass noodles','vermicelli','cellophane noodles','noodles','cereal','granola','muesli','crackers','saltines','graham crackers','tortilla chips','pita chips','potato chips','popcorn','pretzels','walnuts','pecans','peanuts','cashews','pistachios','pine nuts','almonds','hazelnuts','macadamia','brazil nuts','mixed nuts','sunflower seeds','pumpkin seeds','sesame seeds','hemp seeds','chia seeds','flaxseed','poppy seeds','raisins','dried cranberries','dried apricots','dried mango','dried cherries','prunes','medjool dates','dried fruit','green lentils dried','red lentils dried','split peas','dried chickpeas','dried beans','lentils'] },
  { key: 'condiments', label: 'Condiments & Sauces', icon: '🧴', keywords: ['ketchup','yellow mustard','dijon mustard','whole grain mustard','mustard','mayo','mayonnaise','aioli','hot sauce','sriracha','tabasco','crystal hot sauce','worcestershire sauce','worcestershire','soy sauce','tamari','coconut aminos','fish sauce','oyster sauce','hoisin sauce','teriyaki sauce','sweet chili sauce','ponzu','bbq sauce','buffalo sauce','ranch dressing','caesar dressing','italian dressing','balsamic vinegar','balsamic glaze','red wine vinegar','white wine vinegar','apple cider vinegar','rice vinegar','sherry vinegar','champagne vinegar','white vinegar','vinegar','extra virgin olive oil','olive oil','vegetable oil','canola oil','coconut oil','sesame oil','avocado oil','truffle oil','grapeseed oil','peanut oil','cooking spray','lemon juice','lime juice','orange juice concentrate'] },
  { key: 'spices',     label: 'Spices & Baking',     icon: '🧂', keywords: ['kosher salt','sea salt','pink salt','black pepper','white pepper','red pepper flakes','crushed red pepper','cayenne pepper','cayenne','cumin','smoked paprika','sweet paprika','paprika','turmeric','cinnamon','chili powder','ancho chili','chipotle powder','oregano','dried thyme','dried rosemary','dried basil','dried oregano','bay leaves','bay leaf','nutmeg','whole cloves','ground cloves','cardamom','ground coriander','coriander','fennel seeds','mustard seeds','celery seeds','caraway seeds','anise seeds','za\'atar','ras el hanout','five spice','allspice','juniper berries','saffron','curry powder','garam masala','tikka masala','berbere','sumac','dried chili','italian seasoning','herbs de provence','old bay','cajun seasoning','taco seasoning','everything bagel','garlic powder','onion powder','garlic salt','onion salt','salt','pepper','powdered sugar','confectioners sugar','brown sugar','white sugar','raw sugar','coconut sugar','maple syrup','honey','agave','corn syrup','molasses','sugar','vanilla extract','almond extract','pure vanilla','baking powder','baking soda','active dry yeast','instant yeast','cornstarch','arrowroot','tapioca starch','cocoa powder','dutch process cocoa','chocolate chips','dark chocolate','milk chocolate','white chocolate','semi sweet chocolate','unsweetened chocolate','food coloring','cream of tartar','gelatin','agar'] },
  { key: 'beverages',  label: 'Beverages',           icon: '🥤', keywords: ['sparkling water','club soda','tonic water','soda water','orange juice','apple juice','cranberry juice','grape juice','pineapple juice','grapefruit juice','tomato juice','vegetable juice','lemonade','limeade','iced tea','sweet tea','kombucha','cold brew','espresso','coffee','tea bags','herbal tea','green tea','black tea','chai','red wine','white wine','rosé','sparkling wine','prosecco','champagne','beer','lager','ale','stout','vodka','gin','whiskey','bourbon','rum','tequila','mezcal','brandy','triple sec','kahlua','baileys','wine','juice','water'] },
  { key: 'household',  label: 'Household',           icon: '🧹', keywords: ['paper towels','toilet paper','dish soap','laundry detergent','dishwasher pods','sponge','trash bags','zip lock bags','plastic wrap','aluminum foil','parchment paper','wax paper','coffee filters','toothpaste','shampoo','conditioner','body wash','hand soap','cleaning spray','bleach','all purpose cleaner','baking sheets','plastic bags'] },
  { key: 'other',      label: 'Other',               icon: '🛒', keywords: [] },
];

const SECTION_MAP = Object.fromEntries(SECTIONS.map(s => [s.key, s]));

function categorize(name) {
  const lower = name.toLowerCase();
  let bestSection = 'other';
  let bestLen = 0;
  for (const section of SECTIONS) {
    if (section.key === 'other') continue;
    for (const k of section.keywords) {
      // Require word-boundary match so "oil" doesn't match "foil"
      const re = new RegExp(`(?:^|\\s)${k.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}(?:\\s|$|,)`);
      if (re.test(lower) && k.length > bestLen) {
        bestLen = k.length;
        bestSection = section.key;
      }
    }
  }
  return bestSection;
}

// ── Per-user category overrides (localStorage) ───────────────────────────────
function getCatOverrides(uid) {
  try { return JSON.parse(localStorage.getItem(`mise_cat_${uid}`) || '{}'); } catch { return {}; }
}
function saveCatOverride(uid, name, cat) {
  const obj = getCatOverrides(uid);
  obj[name.toLowerCase().trim()] = cat;
  localStorage.setItem(`mise_cat_${uid}`, JSON.stringify(obj));
  return obj;
}
function effectiveCategory(name, category, overrides) {
  return overrides[(name || '').toLowerCase().trim()] || category || categorize(name);
}

const UNITS_RE = /^(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|oz|ounce|ounces|lb|lbs|pound|pounds|g|gram|grams|kg|ml|milliliter|liter|liters|l|clove|cloves|can|cans|bunch|pinch|dash|slice|slices|piece|pieces|sprig|sprigs|stalk|stalks|pkg|package)\b/i;

function parseInput(raw) {
  const s = raw.trim();
  const m = s.match(/^([\d\s\/½⅓¼¾⅔⅛⅜⅝⅞]+(?:\.\d+)?)\s*/);
  if (!m) return { name: s, quantity: '', unit: '' };
  const quantity = m[1].trim();
  const rest = s.slice(m[0].length);
  const unitMatch = rest.match(UNITS_RE);
  if (unitMatch) {
    const unit = unitMatch[0];
    const name = rest.slice(unit.length).trim();
    return { name: name || rest, quantity, unit };
  }
  return { name: rest, quantity, unit: '' };
}

const QUICK_ITEMS = [
  'Milk', 'Eggs', 'Butter', 'Bread', 'Cheese', 'Yogurt',
  'Onion', 'Garlic', 'Tomatoes', 'Lemons', 'Avocados',
  'Chicken', 'Olive oil', 'Salt', 'Pasta', 'Rice',
];

const MONTH_NAMES = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
function startOfWeek(date) {
  const d = new Date(date); d.setDate(d.getDate() - d.getDay()); d.setHours(0,0,0,0); return d;
}
function addDays(date, n) { const d = new Date(date); d.setDate(d.getDate() + n); return d; }
function formatDate(date) { return new Date(date).toISOString().split('T')[0]; }

export default function GroceryList({ user }) {
  const toast = useToast();
  const [list, setList]               = useState(null);
  const [input, setInput]             = useState('');
  const [loading, setLoading]         = useState(true);
  const [adding, setAdding]           = useState(false);
  const [showMealPlan, setShowMealPlan] = useState(false);
  const [mpWeekStart, setMpWeekStart] = useState(() => startOfWeek(new Date()));
  const [mpLoading, setMpLoading]     = useState(false);
  const [mpMeals, setMpMeals]         = useState([]);
  const [mpSelected, setMpSelected]   = useState(new Set());
  const [mpStep, setMpStep]           = useState(0); // 0=recipes, 1=ingredients
  const [mpIngredients, setMpIngredients] = useState([]); // merged ingredient list
  const [mpIngSelected, setMpIngSelected] = useState({}); // idx → bool
  const [mpMultipliers, setMpMultipliers] = useState({}); // meal_plan_id → multiplier
  const [pantry, setPantry]           = useState(() => pantryGet());
  const [pantryOpen, setPantryOpen]   = useState(false);
  const [newPantryItem, setNewPantryItem] = useState('');
  const [cartOpen, setCartOpen]       = useState(false);
  const [editingItem, setEditingItem] = useState(null); // { name, value }
  const [catOverrides, setCatOverrides] = useState({});
  const inputRef = useRef(null);

  useEffect(() => { if (user) { init(); setCatOverrides(getCatOverrides(user.id || user._id)); } }, [user]); // eslint-disable-line

  const changeCategoryOverride = (itemName, newCat) => {
    const uid = user.id || user._id;
    const updated = saveCatOverride(uid, itemName, newCat);
    setCatOverrides({ ...updated });
    toast.success(`Moved to ${SECTION_MAP[newCat].label}`);
  };

  const loadMpMeals = useCallback(async () => {
    if (!user) return;
    setMpLoading(true);
    const start = formatDate(mpWeekStart);
    const end   = formatDate(addDays(mpWeekStart, 6));
    const uid   = user.id || user._id;
    try {
      const r = await apiFetch(`/groceryList/week-meals?user_id=${uid}&start_date=${start}&end_date=${end}`);
      if (r.ok) {
        const meals = await r.json();
        setMpMeals(meals);
        setMpSelected(new Set(meals.map(m => m.meal_plan_id)));
        setMpMultipliers({});
      }
    } catch {}
    setMpLoading(false);
  }, [mpWeekStart, user]); // eslint-disable-line

  useEffect(() => {
    if (showMealPlan) loadMpMeals();
  }, [showMealPlan, loadMpMeals]);

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
    } catch {}
    setLoading(false);
  };

  const addItem = async (itemName, itemQty = '', itemUnit = '') => {
    const parsed = parseInput(input);
    const name     = itemName  || parsed.name;
    const quantity = itemQty   || parsed.quantity;
    const unit     = itemUnit  || parsed.unit;
    if (!name || !list || adding) return;
    setAdding(true);
    try {
      const cat = effectiveCategory(name, null, catOverrides);
      const res = await apiFetch(`/groceryList/${list._id}`, {
        method: 'PUT',
        body: JSON.stringify({ name, quantity, unit, category: cat, checked: false }),
      });
      if (res.ok) {
        setList(l => ({ ...l, items: [...(l.items || []), { name, quantity, unit, category: cat, checked: false }] }));
        if (!itemName) { setInput(''); inputRef.current?.focus(); }
      } else {
        toast.error('Could not add item.');
      }
    } catch {
      toast.error('Could not add item.');
    }
    setAdding(false);
  };

  const quickAdd = (name) => {
    if (!list) return;
    if ((list.items || []).some(i => normalizeIngKey(i.name) === normalizeIngKey(name))) return;
    addItem(name);
  };

  const toggleItem = async (itemName, currentChecked) => {
    setList(l => ({ ...l, items: l.items.map(i => i.name === itemName ? { ...i, checked: !currentChecked } : i) }));
    if (!currentChecked) setCartOpen(true);
    try {
      const res = await apiFetch(`/groceryList/${list._id}/${encodeURIComponent(itemName)}/check`, { method: 'PATCH' });
      if (!res.ok) throw new Error('failed');
    } catch {
      // Roll back on any failure
      setList(l => ({ ...l, items: l.items.map(i => i.name === itemName ? { ...i, checked: currentChecked } : i) }));
      toast.error('Could not update item.');
    }
  };

  const removeItem = async (itemName) => {
    setList(l => ({ ...l, items: l.items.filter(i => i.name !== itemName) }));
    try {
      const res = await apiFetch(`/groceryList/${list._id}/${encodeURIComponent(itemName)}`, { method: 'DELETE' });
      if (!res.ok) throw new Error('failed');
    } catch {
      toast.error('Could not remove item.');
      const r = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
      if (r.ok) { const d = await r.json(); if (d.length) setList(d[0]); }
    }
  };

  const saveEdit = async (oldName, newValue) => {
    const parsed = parseInput(newValue);
    if (!parsed.name.trim()) { setEditingItem(null); return; }
    const updated = { name: parsed.name, quantity: parsed.quantity, unit: parsed.unit, category: categorize(parsed.name) };
    setList(l => ({ ...l, items: l.items.map(i => i.name === oldName ? { ...i, ...updated } : i) }));
    setEditingItem(null);
    // Delete old + add new if name changed
    if (parsed.name !== oldName) {
      try {
        await apiFetch(`/groceryList/${list._id}/${encodeURIComponent(oldName)}`, { method: 'DELETE' });
        await apiFetch(`/groceryList/${list._id}`, {
          method: 'PUT',
          body: JSON.stringify({ ...updated, checked: false }),
        });
      } catch {}
    }
  };

  const clearChecked = async () => {
    if (!list) return;
    setList(l => ({ ...l, items: l.items.filter(i => !i.checked) }));
    setCartOpen(false);
    try {
      await apiFetch(`/groceryList/${list._id}?checked_only=true`, { method: 'DELETE' });
    } catch {
      toast.error('Could not clear checked items.');
      const r = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
      if (r.ok) { const d = await r.json(); if (d.length) setList(d[0]); }
    }
  };

  const clearAll = async () => {
    if (!list || !(list.items || []).length) return;
    setList(l => ({ ...l, items: [] }));
    try {
      await apiFetch(`/groceryList/${list._id}`, { method: 'DELETE' });
    } catch {
      toast.error('Could not clear list.');
      const r = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
      if (r.ok) { const d = await r.json(); if (d.length) setList(d[0]); }
    }
  };

  const reviewIngredients = async () => {
    if (mpSelected.size === 0) return;
    setMpLoading(true);
    const selectedMeals = mpMeals.filter(m => mpSelected.has(m.meal_plan_id));
    // Count how many times each recipe_id appears (same recipe on multiple days)
    const countMap = {};
    for (const m of selectedMeals) countMap[m.recipe_id] = (countMap[m.recipe_id] || 0) + (mpMultipliers[m.meal_plan_id] || 1);
    try {
      const uniqueIds = Object.keys(countMap);
      const fetched = await Promise.all(uniqueIds.map(async id => {
        const r = await apiFetch(`/recipes/${id}`);
        if (!r.ok) return null;
        const d = await r.json();
        return { ...d, _count: countMap[id] };
      }));
      const recipes = fetched.filter(Boolean);
      const merged = mergeIngredients(recipes);
      const p = pantryGet();
      setPantry(p);
      const sel = {};
      merged.forEach((ing, i) => { sel[i] = !pantryMatches(ing.name, p); });
      setMpIngredients(merged);
      setMpIngSelected(sel);
      setMpStep(1);
    } catch { toast.error('Could not load ingredients.'); }
    setMpLoading(false);
  };

  const generateFromMealPlan = async () => {
    const toAdd = mpIngredients.filter((_, i) => mpIngSelected[i]);
    if (toAdd.length === 0) return;
    setMpLoading(true);
    try {
      for (const ing of toAdd) {
        await apiFetch(`/groceryList/${list._id}`, {
          method: 'PUT',
          body: JSON.stringify({ name: ing.name, quantity: ing.quantity, unit: ing.unit, category: effectiveCategory(ing.name, null, catOverrides), checked: false }),
        });
      }
      toast.success(`Added ${toAdd.length} ingredient${toAdd.length !== 1 ? 's' : ''}`);
      const r2 = await apiFetch(`/groceryList/userID/${user.id || user._id}`);
      if (r2.ok) { const d2 = await r2.json(); if (d2.length) setList(d2[0]); }
      setShowMealPlan(false);
      setMpStep(0);
    } catch { toast.error('Something went wrong.'); }
    setMpLoading(false);
  };

  const addToPantry = (item) => {
    const val = item.trim().toLowerCase();
    if (!val || pantry.includes(val)) return;
    const next = [...pantry, val];
    setPantry(next);
    pantrySave(next);
    // re-deselect any ingredient matching the new pantry item
    setMpIngSelected(sel => {
      const updated = { ...sel };
      mpIngredients.forEach((ing, i) => {
        if (pantryMatches(ing.name, next)) updated[i] = false;
      });
      return updated;
    });
  };

  const removeFromPantry = (item) => {
    const next = pantry.filter(p => p !== item);
    setPantry(next);
    pantrySave(next);
  };

  const items        = list?.items || [];
  const checkedCount = items.filter(i => i.checked).length;
  const totalCount   = items.length;
  const pct          = totalCount > 0 ? Math.round((checkedCount / totalCount) * 100) : 0;

  const grouped = {};
  for (const item of items.filter(i => !i.checked)) {
    const key = effectiveCategory(item.name, item.category, catOverrides);
    if (!grouped[key]) grouped[key] = [];
    grouped[key].push({ ...item, _effectiveCat: key });
  }
  const sortedGroups = SECTIONS.map(s => s.key).filter(k => grouped[k]?.length > 0);
  const addedNames   = new Set(items.map(i => i.name.toLowerCase()));

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

      {/* ── Header ──────────────────────────────────────── */}
      <div className="grocery-header">
        <div className="grocery-header-left">
          <h1>Grocery List</h1>
          {!loading && totalCount > 0 && (
            <span className="grocery-progress">{checkedCount}/{totalCount}</span>
          )}
        </div>
        <div className="grocery-header-actions">
          {checkedCount > 0 && (
            <button className="btn-ghost grocery-action-btn" onClick={clearChecked}>
              Clear {checkedCount} checked
            </button>
          )}
          {totalCount > 0 && (
            <button className="btn-ghost grocery-action-btn grocery-action-btn--danger" onClick={clearAll}>
              Clear all
            </button>
          )}
        </div>
      </div>

      {/* ── Progress bar ────────────────────────────────── */}
      {totalCount > 0 && (
        <div className="grocery-progress-bar-wrap">
          <div className="grocery-progress-bar" style={{ width: `${pct}%` }} />
        </div>
      )}

      {/* ── Add bar ─────────────────────────────────────── */}
      <div className="grocery-add-bar">
        <input
          ref={inputRef}
          type="text"
          className="grocery-add-input"
          placeholder='"2 cups flour", "350g chicken", or just "milk"'
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && addItem()}
          disabled={loading}
        />
        <button className="btn-primary" onClick={() => addItem()} disabled={adding || !input.trim() || loading}>
          Add
        </button>
      </div>

      {/* ── Quick-add chips ──────────────────────────────── */}
      <div className="quick-add-row">
        {QUICK_ITEMS.filter(n => !addedNames.has(n.toLowerCase())).map(name => (
          <button key={name} className="quick-add-chip" onClick={() => quickAdd(name)}>
            + {name}
          </button>
        ))}
      </div>

      {/* ── Meal plan generator ──────────────────────────── */}
      <div className="mp-bar">
        <button className={`mp-toggle${showMealPlan ? ' mp-toggle--open' : ''}`} onClick={() => { setShowMealPlan(v => !v); setMpStep(0); }}>
          <span>📅</span> Import from meal plan <span className="mp-toggle-arrow">{showMealPlan ? '▲' : '▼'}</span>
        </button>
      </div>
      {showMealPlan && (() => {
        const end = addDays(mpWeekStart, 6);
        const sm  = MONTH_NAMES[mpWeekStart.getMonth()];
        const em  = MONTH_NAMES[end.getMonth()];
        const allSelected = mpMeals.length > 0 && mpMeals.every(m => mpSelected.has(m.meal_plan_id));
        const selectedIngCount = Object.values(mpIngSelected).filter(Boolean).length;
        return (
          <div className="mp-panel">
            {/* ── Step header ─────────────────────────── */}
            {mpStep === 1 ? (
              <div className="mp-step-header">
                <button className="mp-back-btn" onClick={() => setMpStep(0)}>← Back</button>
                <span className="mp-step-title">Review ingredients</span>
              </div>
            ) : (
              <div className="mp-week-nav">
                <button className="mp-nav-btn" onClick={() => setMpWeekStart(d => addDays(d, -7))}>←</button>
                <span className="mp-week-label">{sm} {mpWeekStart.getDate()} – {sm !== em ? em + ' ' : ''}{end.getDate()}</span>
                <button className="mp-nav-btn" onClick={() => setMpWeekStart(d => addDays(d, 7))}>→</button>
              </div>
            )}

            {mpLoading ? (
              <p className="mp-hint">Loading…</p>
            ) : mpStep === 0 ? (
              /* ── Step 0: recipe selection ───────────── */
              mpMeals.length === 0 ? (
                <p className="mp-hint">No meals planned this week.</p>
              ) : (
                <>
                  <div className="mp-meal-header">
                    <span className="mp-meal-count">{mpSelected.size} of {mpMeals.length} selected</span>
                    <button className="mp-sel-btn" onClick={() =>
                      setMpSelected(allSelected ? new Set() : new Set(mpMeals.map(m => m.meal_plan_id)))
                    }>
                      {allSelected ? 'Deselect all' : 'Select all'}
                    </button>
                  </div>
                  <div className="mp-meal-list">
                    {mpMeals.map(meal => (
                      <div key={meal.meal_plan_id} className={`mp-meal-row${mpSelected.has(meal.meal_plan_id) ? ' mp-meal-row--selected' : ''}`}>
                        <input
                          type="checkbox"
                          className="mp-meal-check"
                          checked={mpSelected.has(meal.meal_plan_id)}
                          onChange={() => {
                            const next = new Set(mpSelected);
                            if (next.has(meal.meal_plan_id)) next.delete(meal.meal_plan_id);
                            else next.add(meal.meal_plan_id);
                            setMpSelected(next);
                          }}
                        />
                        <div className="mp-meal-info">
                          <span className="mp-meal-name">{meal.recipe_name}</span>
                          <span className="mp-meal-meta">
                            {meal.date}
                            {meal.servings > 0 && <> · {meal.servings} serving{meal.servings !== 1 ? 's' : ''}</>}
                          </span>
                        </div>
                        <div className="mp-meal-stepper">
                          <button className="mp-stepper-btn" onClick={() => setMpMultipliers(m => ({...m, [meal.meal_plan_id]: Math.max(1, (m[meal.meal_plan_id]||1) - 1)}))}>−</button>
                          <span className={`mp-stepper-val${(mpMultipliers[meal.meal_plan_id]||1) > 1 ? ' mp-stepper-val--active' : ''}`}>×{mpMultipliers[meal.meal_plan_id] || 1}</span>
                          <button className="mp-stepper-btn" onClick={() => setMpMultipliers(m => ({...m, [meal.meal_plan_id]: Math.min(8, (m[meal.meal_plan_id]||1) + 1)}))}>+</button>
                        </div>
                      </div>
                    ))}
                  </div>
                  <button
                    className="btn-primary mp-generate-btn"
                    onClick={reviewIngredients}
                    disabled={mpSelected.size === 0}
                  >
                    Review ingredients →
                  </button>
                </>
              )
            ) : (
              /* ── Step 1: ingredient review ──────────── */
              <>
                <div className="mp-meal-header">
                  <span className="mp-meal-count">{selectedIngCount} of {mpIngredients.length} ingredients selected</span>
                  <button className="mp-sel-btn" onClick={() => {
                    const allIng = mpIngredients.every((_, i) => mpIngSelected[i]);
                    const next = {};
                    mpIngredients.forEach((_, i) => { next[i] = !allIng; });
                    setMpIngSelected(next);
                  }}>
                    {mpIngredients.every((_, i) => mpIngSelected[i]) ? 'Deselect all' : 'Select all'}
                  </button>
                </div>
                <div className="mp-ing-list">
                  {mpIngredients.map((ing, i) => {
                    const checked = mpIngSelected[i] ?? true;
                    const inPantry = pantryMatches(ing.name, pantry);
                    return (
                      <label key={i} className={`mp-ing-row${checked ? ' mp-ing-row--selected' : ''}`}>
                        <input
                          type="checkbox"
                          className="mp-meal-check"
                          checked={checked}
                          onChange={() => setMpIngSelected(s => ({ ...s, [i]: !checked }))}
                        />
                        <span className="mp-ing-name">{ing.name}</span>
                        {inPantry && !checked && <span className="mp-pantry-badge">in pantry</span>}
                        {(ing.quantity || ing.unit) && (
                          <span className="mp-ing-qty">{[ing.quantity, ing.unit].filter(Boolean).join(' ')}</span>
                        )}
                      </label>
                    );
                  })}
                </div>

                {/* ── Pantry section ───────────────────── */}
                <div className="mp-pantry-section">
                  <button className="mp-pantry-toggle" onClick={() => setPantryOpen(o => !o)}>
                    <span>🏠 My Pantry</span>
                    <span className="mp-toggle-arrow">{pantryOpen ? '▲' : '▼'}</span>
                  </button>
                  {pantryOpen && (
                    <div className="mp-pantry-body">
                      <div className="mp-pantry-chips">
                        {pantry.map(item => (
                          <span key={item} className="mp-pantry-chip">
                            {item}
                            <button className="mp-pantry-remove" onClick={() => removeFromPantry(item)}>×</button>
                          </span>
                        ))}
                      </div>
                      <form className="mp-pantry-add-row" onSubmit={e => { e.preventDefault(); addToPantry(newPantryItem); setNewPantryItem(''); }}>
                        <input
                          className="mp-pantry-input"
                          value={newPantryItem}
                          onChange={e => setNewPantryItem(e.target.value)}
                          placeholder="Add item…"
                        />
                        <button type="submit" className="mp-pantry-add-btn" disabled={!newPantryItem.trim()}>Add</button>
                      </form>
                    </div>
                  )}
                </div>

                <button
                  className="btn-primary mp-generate-btn"
                  onClick={generateFromMealPlan}
                  disabled={selectedIngCount === 0}
                >
                  Add {selectedIngCount} ingredient{selectedIngCount !== 1 ? 's' : ''} to list
                </button>
              </>
            )}
          </div>
        );
      })()}

      {/* ── Content ─────────────────────────────────────── */}
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
                    <GroceryItemRow
                      key={idx}
                      item={{ ...item, category: item._effectiveCat }}
                      editing={editingItem?.name === item.name}
                      editValue={editingItem?.name === item.name ? editingItem.value : ''}
                      onEditStart={() => setEditingItem({ name: item.name, value: [item.quantity, item.unit, item.name].filter(Boolean).join(' ') })}
                      onEditChange={v => setEditingItem(e => ({ ...e, value: v }))}
                      onEditSave={() => saveEdit(item.name, editingItem.value)}
                      onEditCancel={() => setEditingItem(null)}
                      onToggle={() => toggleItem(item.name, item.checked)}
                      onRemove={() => removeItem(item.name)}
                      onCategoryChange={newCat => changeCategoryOverride(item.name, newCat)}
                    />
                  ))}
                </div>
              </div>
            );
          })}

          {/* ── In cart (collapsible) ───────────────────── */}
          {checkedCount > 0 && (
            <div className="grocery-category grocery-category--checked">
              <button className="grocery-category-header grocery-category-header--btn" onClick={() => setCartOpen(o => !o)}>
                <span className="grocery-category-icon">✓</span>
                <span className="grocery-category-label">In cart</span>
                <span className="grocery-category-count">{checkedCount}</span>
                <span className="grocery-cart-arrow">{cartOpen ? '▲' : '▼'}</span>
              </button>
              {cartOpen && (
                <div className="grocery-category-items">
                  {items.filter(i => i.checked).map((item, idx) => (
                    <GroceryItemRow
                      key={idx}
                      item={item}
                      editing={false}
                      onToggle={() => toggleItem(item.name, item.checked)}
                      onRemove={() => removeItem(item.name)}
                    />
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function GroceryItemRow({ item, editing, editValue, onEditStart, onEditChange, onEditSave, onEditCancel, onToggle, onRemove, onCategoryChange }) {
  const qtyLabel = [item.quantity, item.unit].filter(Boolean).join(' ');
  const editRef  = useRef(null);
  const catRef   = useRef(null);
  const [showCatMenu, setShowCatMenu] = useState(false);

  useEffect(() => { if (editing) editRef.current?.focus(); }, [editing]);

  useEffect(() => {
    if (!showCatMenu) return;
    const handler = e => { if (catRef.current && !catRef.current.contains(e.target)) setShowCatMenu(false); };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [showCatMenu]);

  const section = SECTION_MAP[item.category] || SECTION_MAP.other;

  return (
    <div className={`grocery-item${item.checked ? ' grocery-item--checked' : ''}`}>
      <button className="grocery-checkbox" onClick={onToggle} aria-label="Toggle">
        <span className="grocery-checkbox-inner">{item.checked ? '✓' : ''}</span>
      </button>

      {editing ? (
        <input
          ref={editRef}
          className="grocery-edit-input"
          value={editValue}
          onChange={e => onEditChange(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') onEditSave(); if (e.key === 'Escape') onEditCancel(); }}
          onBlur={onEditSave}
        />
      ) : (
        <span className="grocery-item-name" onDoubleClick={onEditStart}>{item.name}</span>
      )}

      {!editing && qtyLabel && (
        <span className="grocery-item-qty" onClick={onEditStart}>{qtyLabel}</span>
      )}

      {!editing && onCategoryChange && (
        <div className="grocery-cat-wrap" ref={catRef}>
          <button
            className="grocery-cat-btn"
            onClick={() => setShowCatMenu(v => !v)}
            title={`Move from ${section.label}`}
          >
            {section.icon}
          </button>
          {showCatMenu && (
            <div className="grocery-cat-menu">
              <div className="grocery-cat-menu-label">Move to…</div>
              {SECTIONS.filter(s => s.key !== 'other' && s.key !== item.category).map(s => (
                <button
                  key={s.key}
                  className="grocery-cat-option"
                  onClick={() => { onCategoryChange(s.key); setShowCatMenu(false); }}
                >
                  <span>{s.icon}</span> {s.label}
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {!editing && (
        <button className="grocery-remove" onClick={onRemove} aria-label="Remove">✕</button>
      )}
    </div>
  );
}

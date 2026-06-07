# StarRating Component

A small, reusable star-rating widget used across the web frontend to both **display** a recipe's average rating and **collect** a rating from a logged-in user.

Source: [src/components/StarRating.js](../src/components/StarRating.js) · Styles: [src/components/css/StarRating.css](../src/components/css/StarRating.css)

## Overview

mise uses a **3-star** rating scale (not the usual 5). The same component renders in two modes, chosen automatically based on whether an `onChange` handler is supplied:

- **Interactive mode** (`onChange` provided) — renders `<button>` stars with hover preview and click-to-rate. Used on the recipe detail page so a signed-in user can rate a recipe.
- **Read-only mode** (no `onChange`) — renders static `<span>` stars. Used in recipe lists, cards, profiles, and individual review rows to show an existing rating.

## Props

| Prop        | Type       | Default | Description                                                                 |
|-------------|------------|---------|-----------------------------------------------------------------------------|
| `rating`    | `number`   | `0`     | Current rating value (1–3). Drives how many stars are filled.               |
| `onChange`  | `function` | —       | Callback `(newRating) => void`. **Presence of this prop enables interactive mode.** |
| `size`      | `string`   | `'md'`  | Size variant; applied as the CSS class `star-rating--{size}` (e.g. `sm`, `md`, `lg`). |
| `showScore` | `boolean`  | `false` | When true and `rating > 0`, appends the numeric score (`rating.toFixed(1)`). |
| `showCount` | `boolean`  | `false` | When true and `count > 0`, appends the rating count in parentheses, e.g. `(42)`. |
| `count`     | `number`   | `0`     | Number of ratings, shown when `showCount` is enabled.                       |

## Behavior

- **Hover preview** (interactive only): hovering a star previews that rating via local `hovered` state; the displayed fill is `hovered || rating`.
- **Toggle off**: clicking the star equal to the current `rating` calls `onChange(0)`, clearing the rating. Clicking any other star `n` calls `onChange(n)`.
- **Rounding**: in read-only mode the fill uses `Math.round(display)`, so a fractional average like `2.4` shows 2 filled stars while the numeric `showScore` label still reflects the precise value.
- **Accessibility**: interactive stars are real buttons with `aria-label="Rate N star(s)"`.

## Usage

Display an average on a recipe card (read-only, with numeric score):

```jsx
<StarRating rating={recipe.avg_rating || 0} showScore={recipe.avg_rating > 0} size="sm" />
```

Collect a rating on the recipe detail page (interactive only when logged in):

```jsx
<StarRating
  rating={userRating || 0}
  onChange={user ? handleRate : undefined}
  size="lg"
/>
```

Current consumers: [RecipeDetails.js](../src/pages/RecipeDetails.js) (interactive rating + per-review display), [Recipes.js](../src/pages/Recipes.js) and [ProfilePage.js](../src/pages/ProfilePage.js) (read-only card scores).

## Backend integration

The component itself is presentation-only — persistence happens in the page's `onChange` handler against the ratings API ([backend/routers/ratings.py](../backend/routers/ratings.py)):

- `POST /ratings/{recipe_id}` — upsert the current user's rating (body `{ rating: 1–3 }`, validated server-side with `ge=1, le=3`).
- `DELETE /ratings/{recipe_id}` — remove the current user's rating.
- `GET /ratings/{recipe_id}` — fetch the recipe's rating summary / the viewer's own rating.

Notes on server behavior:
- A `(recipe_id, user_id)` unique index enforces **one rating per user per recipe** (created on startup in `main.py`).
- After any change, the backend recalculates and caches `avg_rating` and `rating_count` on the recipe document, which is what read-only `StarRating` instances display.
- Ratings on a **forked/copied** recipe are redirected to the original recipe (`_resolve_recipe_id`), so all versions share one rating pool.

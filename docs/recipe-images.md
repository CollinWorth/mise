# Recipe Images

How recipe images are ingested, stored, served, and rendered — and the work done to make them reliable.

## Goal

Every recipe image — whether **uploaded** from a device, **pasted** as an external URL, or **scraped/AI-imported** — should be copied into our own database and served from our own API, so images never depend on (or break with) an external host, the reverse-proxy prefix, or the deploy environment.

## Storage model

- Images live in the MongoDB **`images`** collection as raw bytes: `{ _id, data, content_type }`.
- Recipe documents store only a **relative** string path in `image_url` (e.g. `/images/{id}`), never the bytes and never an absolute host.
- Served by a single endpoint: `GET /images/{image_id}` ([backend/main.py](../backend/main.py)).

### Why relative paths (the key fix)

Previously, upload/import returned **absolute** URLs built from `_public_base_url()` (which used `BASE_URL` or `request.base_url`). In production the frontend talks to `https://misekitchen.duckdns.org/api`, but `BASE_URL` was empty, so the backend handed back `https://misekitchen.duckdns.org/images/{id}` — **missing the `/api` reverse-proxy prefix**. nginx routes only `/api/*` to the backend, so those image URLs hit the frontend and 404. That was the "uploading images doesn't work" symptom (the bytes were stored fine; the returned link was unreachable).

Now all image URLs are stored **relative** and the frontend's `imgUrl()` ([src/api.js](../src/api.js)) prepends the configured `REACT_APP_API_URL` (which already includes `/api`) at render time. This is host- and proxy-prefix-independent and needs no `BASE_URL` configuration.

## The three ingestion paths

| Source | Where | Result |
|--------|-------|--------|
| **Direct upload** | `POST /recipes/upload-image` (multipart) | bytes → `images` collection → returns `{ "url": "/images/{id}" }` |
| **Pasted URL** | `image_url` field on Add/Edit form | archived into `images` on save |
| **Scrape / AI import** | scraper/vision sets `image_url` | archived into `images` on save |

Archiving for the latter two happens in **`_maybe_archive_image(url)`** ([backend/routers/recipes.py](../backend/routers/recipes.py)), called from `create_recipe`, `update_recipe`, and `save_recipe_to_collection`. Its rules:

1. Empty / relative path → returned unchanged (already ours).
2. Absolute URL pointing at our own host (`localhost`/`127.0.0.1`, or the `BASE_URL` host) → reduced to its relative path.
3. Genuine external `http(s)` image → downloaded, content-type verified to be `image/*`, stored in `images`, returned as `/images/{id}`.
4. Any failure (non-200, non-image, network error) → original URL returned unchanged (non-fatal).

## Rendering

The frontend never uses `image_url` raw — every `<img>` wraps it in `imgUrl()`. `imgUrl()` is permissive but **carefully scoped** to avoid hijacking external recipe-site URLs:

1. If the string contains `/images/{24-hex-ObjectId}` anywhere, extract that and prepend `REACT_APP_API_URL`. The 24-hex-ObjectId shape is what our backend emits and is vanishingly unlikely to appear in a foreign CDN URL by coincidence; a trailing boundary check (`(?![0-9a-fA-F])`) prevents matching the 24-char prefix of a longer hex string.
2. Else if the string **starts with** `/uploads/`, prepend the API base (relative legacy path). Crucially, it only matches at the start — not mid-URL — so `https://www.thekitchn.com/wp-content/uploads/…/photo.jpg` is **not** hijacked.
3. Else return unchanged (genuine external image; browser fetches directly).

Cases handled correctly:

- `/images/{id}` → `${API}/images/{id}` (canonical)
- `https://misekitchen.duckdns.org/images/{id}` (legacy absolute, missing `/api`) → `${API}/images/{id}`
- `railway-prod-host/images/{id}` (user-pasted half-URL, no scheme) → `${API}/images/{id}`
- `https://localhost:8000/images/{id}` (old dev) → `${API}/images/{id}`
- `https://assets.bonappetit.com/photos/.../recipe.jpg` (external CDN) → unchanged
- `https://www.thekitchn.com/wp-content/uploads/.../photo.jpg` (Wordpress CDN) → unchanged

**Prior bug fixed (2026-06-08):** an earlier overly-broad version of `imgUrl()` extracted any `/images/...` or `/uploads/...` segment from anywhere in the URL, including external CDN URLs. That broke every scraped recipe whose image URL happened to use one of those path words. The current narrower match (ObjectId-shape only, and `/uploads/` only as a path prefix) is the fix.

See Add/Edit previews ([src/pages/AddRecipe.js](../src/pages/AddRecipe.js), [src/pages/EditRecipe.js](../src/pages/EditRecipe.js)). The image URL input is `type="text"` (not `type="url"`) so the browser doesn't block submit when a user pastes a half-URL — the backend normalizes on save.

## Save-time normalization (defensive)

`_maybe_archive_image` ([backend/routers/recipes.py](../backend/routers/recipes.py)) has a fast-path before its existing scheme/host checks: **if the URL contains `/images/{24-hex-ObjectId}` anywhere, it's normalized to that relative path** and short-circuits the rest of the function. ObjectId-shape paths are unambiguously ours (it's the exact shape `POST /recipes/upload-image` and the archiver emit), so this is safe regardless of scheme, host, or proxy prefix. After this check, the existing logic handles:

1. Empty / scheme-less / pure-relative → returned unchanged.
2. Absolute URL on our own host (`localhost`/`127.0.0.1` or `BASE_URL` host) → reduced to its path.
3. Genuine external `http(s)` image → downloaded and archived to `/images/{id}`.
4. Failures → original URL returned (non-fatal).

The net result: whatever shape the user pastes, the DB ends up with a clean relative `/images/{id}` whenever the input was actually ours, and renders correctly even before save.

## Mobile (web app) camera & photo library

The upload control is a hidden `<input type="file" accept="image/*">` triggered by an "↑ Upload" button. On mobile Safari/Chrome, `accept="image/*"` makes the OS present the native chooser with **Take Photo**, **Photo Library**, and **Choose File** — so camera and library both work with no extra code. We intentionally do **not** set the `capture` attribute, which would force the camera and remove the library option.

## The three ingestion methods, end-to-end

Reference walkthrough for what actually happens for each of the three ways a recipe gets an image. All three paths converge on the same canonical storage shape: a relative `/images/{ObjectId}` in the recipe document, with the bytes in the `images` collection.

### 1. Direct upload (file picker / phone camera)

1. Frontend `handleImageUpload` ([src/pages/AddRecipe.js](../src/pages/AddRecipe.js), [src/pages/EditRecipe.js](../src/pages/EditRecipe.js)) POSTs the file to `POST /recipes/upload-image` as multipart.
2. Backend `upload_image` ([backend/routers/recipes.py:1036](../backend/routers/recipes.py)) validates `image/*` content type (→ 400 if not), enforces ≤ `MAX_IMAGE_BYTES` (10 MB → 413 if not), inserts the raw bytes into the `images` collection, returns `{ "url": "/images/{ObjectId}" }`.
3. Frontend sets `form.image_url = "/images/{id}"`. Preview is instant (`imgUrl()` matches the 24-hex pattern → `${API}/images/{id}`).
4. On save, `_maybe_archive_image` sees `/images/{id}`, hits the ObjectId fast-path, returns unchanged.
5. **Stored as:** `/images/{id}`.

### 2. Pasted URL (typed into the Image field)

The input is `type="text"`, so the browser doesn't block submit regardless of what's in there. Three real sub-cases for whatever string the user types:

**2a. Genuine external image** (`https://example.com/photo.jpg`)
- Preview: `imgUrl()` returns the URL unchanged → browser fetches the external host directly.
- On save: `_maybe_archive_image` skips the ObjectId fast-path, has a scheme, hostname is not ours → falls through to the "external" branch. Downloads with `httpx`, verifies `Content-Type: image/*`, stores bytes in `images`, returns `/images/{newId}`. On any failure (network, 404, non-image, timeout) the original URL is kept (non-fatal — the recipe still saves).
- **Stored as:** `/images/{newId}` on success, original URL on failure.

**2b. Legacy / half-URL pointing at one of our images** (`mise-production-…/images/{id}`, `https://misekitchen.duckdns.org/images/{id}` (no `/api`), `localhost:8000/images/{id}`)
- Preview: `imgUrl()` finds the embedded `/images/{24-hex}` segment, returns `${API}/images/{id}` → loads via the proxy.
- On save: `_maybe_archive_image`'s ObjectId fast-path matches → returns just `/images/{id}` (strips the host/scheme/prefix junk).
- **Stored as:** `/images/{id}` (clean).

**2c. Garbage / non-URL string** (`not a url`)
- Preview: `imgUrl()` returns the string unchanged → broken `<img>` (the small `?` placeholder).
- On save: no ObjectId match, `urlparse` finds no scheme, doesn't start with `http` → returned unchanged.
- **Stored as:** the raw string. Recipe saves; image just doesn't display.

### 3. Scrape / AI import (URL scrape, Claude vision photo, free-text parse)

- The scraper/vision step (`/recipes/scrape`, `/recipes/scrape-smart`, `/recipes/parse-photo`, `/recipes/parse-text`) populates `image_url` with whatever the source provided — usually an external `https://…` URL from the recipe site, sometimes a relative path we already host.
- That value flows through `create_recipe` → `_maybe_archive_image`. From there the logic is identical to method 2 above: external URLs are downloaded and archived (case 2a behavior), URLs that already contain our ObjectId pattern are reduced to the relative form (case 2b), failures fall through preserving the original URL.
- **Stored as:** `/images/{newId}` for successful archives, original URL for failures.

### One unifying fact

After save, the canonical shape in the DB is **`/images/{ObjectId}`** for anything that succeeded in getting into our `images` collection (regardless of which method). `imgUrl()` only needs to handle that one shape on render — every other shape it sees is either a true external URL (pass through) or a junk string (broken image, no harm done to layout).

## Display stability (scroll-jump fix)

Until 2026-06-08 the Discover page's masonry grid (`.ex-grid`, CSS multi-column) made the page visibly jump as the user scrolled: image cards had `width: 100%; height: auto` with no reserved space, so each lazy-loaded image expanded its card from zero to its natural height, pushing every later card in the same CSS column down. A custom `LazyImage` with `rootMargin: 1500px` (load a viewport ahead) helped on slow scrolls but fast-flick scrolls outran the buffer, and the failure path was worse — when an image errored, the entire `.ex-card-img` block unmounted via the `failedImages` set, collapsing the card and shifting everything below.

The fix (option 3 from `Upcoming Features.md` — uniform aspect-ratio):

1. **Reserve image height at render time.** `.ex-card-img` ([src/pages/css/ExplorePage.css:249](../src/pages/css/ExplorePage.css)) now sets `aspect-ratio: 4 / 3` and a subtle `background: var(--surface-raised)` so the box is always at its final size from first paint, before the image bytes arrive. The `<img>` inside is `width: 100%; height: 100%; object-fit: cover` so the image fills the reserved box without distortion (matches what spotlight and feed posts already do).
2. **Keep the box mounted on image error.** [src/pages/DiscoverPage.js](../src/pages/DiscoverPage.js) main `ex-grid` map now decides the card *layout* from `recipe.image_url` alone (mount-time and stable), and uses `failedImages` only to swap the `<LazyImage>` for a cuisine-colored placeholder *inside* the same `.ex-card-img` box. The card height never changes after mount.
3. **Cheaper compositor usage.** Moved `will-change: transform` off every grid image and onto the `:hover` rule (`.ex-card:hover .ex-card-img img`), so we're not paying for a separate compositor layer per card just in case the user hovers.
4. **Reverted custom IntersectionObserver, back to native lazy.** [src/components/LazyImage.js](../src/components/LazyImage.js) is now a thin passthrough that renders `<img loading={eager ? 'eager' : 'lazy'} decoding="async">`. The original reason for the custom observer (load earlier than native lazy, ~1500px ahead, so the column reflow happened off-screen) is moot once height is reserved. Native lazy is faster in two ways: the browser auto-eager-loads any image already in the viewport at page load (so first-screen images don't wait for `useEffect` → observer-fires → re-render-with-src round-trip), and `decoding="async"` keeps image decoding off the main thread. The `eager` prop is preserved so above-the-fold callsites can still force immediate load. **Subtle CSS-columns gotcha:** `eager={idx < 8}` only forces the first 8 items by index, which in a CSS multi-column layout *all flow into column 1* (columns fill top-to-bottom, not row-major). The first viewport always *contains* items from every column though, and native lazy auto-eager-loads anything in viewport, so this is fine in practice — but if you ever need explicit eager loading for above-the-fold cards across all columns, bump the threshold significantly (e.g. 24) or compute it from viewport row count × column count.

### What I tried and reverted: `content-visibility: auto`
Briefly added `content-visibility: auto; contain-intrinsic-size: 360px 320px` to `.ex-card` for off-screen layout skip. It was *catastrophic* on this layout — `content-visibility` uses the `contain-intrinsic-size` placeholder for off-screen cards, then re-lays them out at actual size as they scroll into view. In a CSS multi-column layout that re-balances columns mid-scroll, producing a visible glitching/jitter as cards jump between columns. Do not add this back on the masonry grid. If you ever want it, it's safe only on layouts where each item's size is known up-front (e.g. a uniform CSS grid with fixed row height).

### What this changes visually
Discover image cards now all have the same image-region aspect ratio (4:3). Text-only cards (no image) still vary in body height, so the masonry feel is preserved overall — just the image strips are uniform. If you want true per-image masonry like Pinterest, option 1 in `Upcoming Features.md` is the path (store image w/h on upload/import, render `aspect-ratio: w/h` per image).

### Pages not (yet) covered
- **Personal Recipes grid** (`.recipe-card-img` in [src/pages/css/Recipes.css](../src/pages/css/Recipes.css)) has the same architecture and the same theoretical jump, but doesn't use `loading="lazy"` so all images request together. Less acute. Applying the same `aspect-ratio: 4/3` + `object-fit: cover` treatment is a one-CSS-block change if it ever becomes noticeable.
- **Spotlight row** (`.ex-spotlight-img`) already used a fixed `height: 160px` — stable from the start.
- **Feed posts** (`.feed-post-img img`) already used `aspect-ratio: 4/3; object-fit: cover` — stable from the start.

## Status

### Done
- [x] Images stored in MongoDB `images` collection (not the ephemeral `uploads/` dir).
- [x] Scraped and pasted-URL images copied into the DB on save (`_maybe_archive_image`).
- [x] Upload fixed: endpoint returns a **relative** `/images/{id}` path; frontend `imgUrl()` builds the correct absolute URL per environment. Removed the `_public_base_url` / `BASE_URL` dependency.
- [x] Upload validation: rejects non-image content types (400) and images over `MAX_IMAGE_BYTES` (10 MB → 413), keeping docs under MongoDB's 16 MB BSON limit.
- [x] Mobile camera/library: handled by `accept="image/*"` (verified markup; no `capture` so the user can choose).
- [x] **Forgiving URL handling for legacy / broken-shape image links.** `imgUrl()` now extracts any embedded `/images/...` or `/uploads/...` segment from arbitrary strings, so legacy DB rows with absolute Railway/duckdns URLs and user-pasted half-URLs (e.g. missing `https://`) render correctly without a backfill. The Add/Edit image input is `type="text"` so non-URL-shaped strings don't block form submit. `_maybe_archive_image` has a matching fast-path: any URL containing `/images/{24-hex}` is normalized to the relative path at save time, so storage stays clean going forward.

### Verified
- Local end-to-end test: `POST /recipes/upload-image` → returns `/images/{id}` → `GET /images/{id}` serves the bytes (200, correct content-type). External-URL archiving exercised via `_maybe_archive_image`.

### Remaining / follow-ups
- **Server-side downscaling/compression** (e.g. Pillow): cap dimensions and re-encode so large phone photos shrink before hitting the 16 MB limit. Currently only a hard size cap exists.
- **Backfill legacy data** *(now cosmetic, not functional).* The forgiving `imgUrl()` + save-time normalization above makes legacy absolute URLs **render correctly** without touching the DB. A one-off migration to rewrite stored URLs to canonical `/images/{id}` form is still nice for cleanliness, but no longer required to fix display. Vanished `/uploads/...` links remain a separate problem — those files don't exist on disk and can't be recovered without re-fetching from the original source.
- **Consider GridFS** if images regularly approach the BSON limit (or to stream large files), instead of inlining bytes in a single document.
- **Orphan cleanup**: images in the collection are never deleted when a recipe is deleted or its image replaced; a periodic sweep could reclaim them.

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

The frontend never uses `image_url` raw — every `<img>` wraps it in `imgUrl()`, which prefixes `/images/` and `/uploads/` paths (and rewrites legacy `localhost` URLs) with `REACT_APP_API_URL`. See Add/Edit previews ([src/pages/AddRecipe.js](../src/pages/AddRecipe.js), [src/pages/EditRecipe.js](../src/pages/EditRecipe.js)).

## Mobile (web app) camera & photo library

The upload control is a hidden `<input type="file" accept="image/*">` triggered by an "↑ Upload" button. On mobile Safari/Chrome, `accept="image/*"` makes the OS present the native chooser with **Take Photo**, **Photo Library**, and **Choose File** — so camera and library both work with no extra code. We intentionally do **not** set the `capture` attribute, which would force the camera and remove the library option.

## Status

### Done
- [x] Images stored in MongoDB `images` collection (not the ephemeral `uploads/` dir).
- [x] Scraped and pasted-URL images copied into the DB on save (`_maybe_archive_image`).
- [x] Upload fixed: endpoint returns a **relative** `/images/{id}` path; frontend `imgUrl()` builds the correct absolute URL per environment. Removed the `_public_base_url` / `BASE_URL` dependency.
- [x] Upload validation: rejects non-image content types (400) and images over `MAX_IMAGE_BYTES` (10 MB → 413), keeping docs under MongoDB's 16 MB BSON limit.
- [x] Mobile camera/library: handled by `accept="image/*"` (verified markup; no `capture` so the user can choose).

### Verified
- Local end-to-end test: `POST /recipes/upload-image` → returns `/images/{id}` → `GET /images/{id}` serves the bytes (200, correct content-type). External-URL archiving exercised via `_maybe_archive_image`.

### Remaining / follow-ups
- **Server-side downscaling/compression** (e.g. Pillow): cap dimensions and re-encode so large phone photos shrink before hitting the 16 MB limit. Currently only a hard size cap exists.
- **Backfill legacy data**: existing recipes with old absolute `https://…duckdns.org/images/{id}` (no `/api`) or vanished `/uploads/...` links remain broken until re-fetched/rewritten. A one-off migration could re-archive from source where available and rewrite stored URLs to relative paths.
- **Consider GridFS** if images regularly approach the BSON limit (or to stream large files), instead of inlining bytes in a single document.
- **Orphan cleanup**: images in the collection are never deleted when a recipe is deleted or its image replaced; a periodic sweep could reclaim them.

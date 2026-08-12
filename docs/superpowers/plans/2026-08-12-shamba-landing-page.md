# Shamba+ Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a static Shamba+ landing page under `docs/`, served at `https://shamba.samtama.lol/`, that names and explains the app and links to the existing legal pages — fixing all four Google OAuth verification issues.

**Architecture:** Plain HTML/CSS, no build step, no JS framework — same approach as the existing `docs/support/legal/*.html` pages. New files (`docs/index.html`, `docs/404.html`, `docs/styles.css`, `docs/assets/*`) sit alongside the existing legal pages inside the `docs/` GitHub Pages source.

**Tech Stack:** Static HTML5 + CSS3 (custom properties for theming, `prefers-color-scheme` for dark mode). No JavaScript.

## Global Constraints

- No JS framework, no client-side build tooling — everything is static HTML/CSS, matching `docs/support/legal/`.
- All new site files live under `docs/` (the existing GitHub Pages source folder).
- Contact email everywhere on the site must be `ngigi.nyongo@gmail.com` — no `support@samtama.lol` references may remain.
- Color tokens must match `docs/support/legal/style.css` exactly, for light/dark consistency across the whole site:
  light `--bg:#f7f5f0 --surface:#ffffff --text:#23291f --muted:#5b6357 --accent:#2e7d32 --border:#e3e0d6 --danger:#c62828`;
  dark `--bg:#14170f --surface:#1c2016 --text:#eef1e8 --muted:#a4ac9a --accent:#6fcf73 --border:#2c3223 --danger:#ef5350`.
- Internal links use root-relative paths (`/`, `/styles.css`, `/assets/...`, `/support/legal/...`) since `docs/` is the site root once served (locally via `python3 -m http.server --directory docs`, in production via the custom domain).
- Domain: `shamba.samtama.lol`. DNS (`shamba` → `ngigin.github.io`, DNS-only/unproxied) is already configured in Cloudflare.

---

### Task 1: Site assets and custom domain file

**Files:**
- Create: `docs/CNAME`
- Create: `docs/assets/logo.png` (copy of `assets/images/farmer_app.png`)
- Create: `docs/assets/hero.jpg` (copy of `assets/images/shamba_feature_graphic.jpg`)

**Interfaces:**
- Consumes: `assets/images/farmer_app.png` (1254×1254 PNG, existing app icon source), `assets/images/shamba_feature_graphic.jpg` (1168×784 JPEG, existing Play Store feature graphic).
- Produces: `/assets/logo.png` and `/assets/hero.jpg` as stable root-relative paths that Task 3's HTML references directly. `docs/CNAME` is read by GitHub Pages, not by any other task.

- [ ] **Step 1: Verify the files don't exist yet**

Run: `ls docs/CNAME docs/assets/logo.png docs/assets/hero.jpg 2>&1`
Expected: three "No such file or directory" errors.

- [ ] **Step 2: Create the assets directory and copy images**

```bash
mkdir -p docs/assets
cp assets/images/farmer_app.png docs/assets/logo.png
cp assets/images/shamba_feature_graphic.jpg docs/assets/hero.jpg
printf 'shamba.samtama.lol' > docs/CNAME
```

- [ ] **Step 3: Verify the files now exist with correct dimensions**

Run: `identify docs/assets/logo.png docs/assets/hero.jpg && cat docs/CNAME`
Expected:
```
docs/assets/logo.png PNG 1254x1254 ...
docs/assets/hero.jpg JPEG 1168x784 ...
shamba.samtama.lol
```
(no trailing newline after `shamba.samtama.lol` — GitHub Pages tolerates either, but keep it exact)

- [ ] **Step 4: Commit**

```bash
git add docs/CNAME docs/assets/logo.png docs/assets/hero.jpg
git commit -m "feat: add landing page assets and custom domain file"
```

---

### Task 2: Landing page stylesheet

**Files:**
- Create: `docs/styles.css`

**Interfaces:**
- Consumes: nothing (pure CSS).
- Produces: classes `.wrap`, `.nav`, `.nav-inner`, `.brand`, `.brand .mark-img`, `.brand .name`, `.nav nav`, `.hero`, `.hero h1`, `.hero .tagline`, `.hero .lede`, `.hero-image`, `.features`, `.feature-card`, `.site-footer`, `.footer-inner`, `.copyright` — consumed by Task 3's `docs/index.html` and `docs/404.html`.

- [ ] **Step 1: Verify the file doesn't exist yet**

Run: `ls docs/styles.css 2>&1`
Expected: "No such file or directory"

- [ ] **Step 2: Write the stylesheet**

Create `docs/styles.css`:

```css
:root {
  --bg: #f7f5f0;
  --surface: #ffffff;
  --text: #23291f;
  --muted: #5b6357;
  --accent: #2e7d32;
  --border: #e3e0d6;
  --danger: #c62828;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14170f;
    --surface: #1c2016;
    --text: #eef1e8;
    --muted: #a4ac9a;
    --accent: #6fcf73;
    --border: #2c3223;
    --danger: #ef5350;
  }
}

* { box-sizing: border-box; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.6;
}

a { color: var(--accent); }

.wrap {
  max-width: 960px;
  margin: 0 auto;
  padding: 0 20px;
}

/* Nav */
.nav {
  position: sticky;
  top: 0;
  background: var(--bg);
  border-bottom: 1px solid var(--border);
  z-index: 10;
}

.nav-inner {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding-top: 16px;
  padding-bottom: 16px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  color: var(--text);
}

.brand .mark-img {
  border-radius: 8px;
  display: block;
}

.brand .name {
  font-weight: 700;
  font-size: 18px;
}

.nav nav {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
}

.nav nav a {
  color: var(--text);
  text-decoration: none;
  font-size: 0.95rem;
}

.nav nav a:hover { color: var(--accent); }

/* Hero */
.hero {
  padding: 56px 20px 40px;
  text-align: center;
}

.hero h1 {
  font-size: clamp(2rem, 5vw, 3rem);
  margin: 0 0 8px;
}

.hero .tagline {
  color: var(--accent);
  font-weight: 600;
  font-size: 1.2rem;
  margin: 0 0 20px;
}

.hero .lede {
  max-width: 640px;
  margin: 0 auto 36px;
  color: var(--muted);
  font-size: 1.05rem;
}

.hero-image {
  width: 100%;
  max-width: 960px;
  height: auto;
  border-radius: 16px;
  border: 1px solid var(--border);
  display: block;
  margin: 0 auto;
}

/* Features */
.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 20px;
  padding: 48px 20px 64px;
}

.feature-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 28px 24px;
}

.feature-card h2 {
  margin: 0 0 8px;
  font-size: 1.15rem;
  color: var(--accent);
}

.feature-card p {
  margin: 0;
  color: var(--text);
}

/* Footer */
.site-footer {
  border-top: 1px solid var(--border);
  margin-top: 20px;
}

.footer-inner {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  padding: 40px 20px;
  text-align: center;
}

.footer-inner .mark-img { border-radius: 8px; }

.site-footer nav {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 18px;
}

.site-footer nav a {
  color: var(--muted);
  text-decoration: none;
  font-size: 0.9rem;
}

.site-footer nav a:hover { color: var(--accent); }

.copyright {
  color: var(--muted);
  font-size: 0.85rem;
  margin: 0;
}

.copyright a { color: var(--muted); }
```

- [ ] **Step 3: Verify braces are balanced (sanity check for a syntax slip)**

Run: `grep -o "{" docs/styles.css | wc -l && grep -o "}" docs/styles.css | wc -l`
Expected: both numbers equal (33 and 33).

- [ ] **Step 4: Commit**

```bash
git add docs/styles.css
git commit -m "feat: add landing page stylesheet"
```

---

### Task 3: Landing page and 404 page

**Files:**
- Create: `docs/index.html`
- Create: `docs/404.html`

**Interfaces:**
- Consumes: `docs/styles.css` classes from Task 2; `/assets/logo.png`, `/assets/hero.jpg` from Task 1; links to `/support/legal/privacy-policy.html`, `/support/legal/terms-of-service.html`, `/support/legal/delete-account.html` (existing files, unmodified paths).
- Produces: `https://shamba.samtama.lol/` as the OAuth consent screen's "Application home page" and `#top` / `#features` anchors used by the nav.

- [ ] **Step 1: Verify the files don't exist yet**

Run: `ls docs/index.html docs/404.html 2>&1`
Expected: two "No such file or directory" errors.

- [ ] **Step 2: Write the landing page**

Create `docs/index.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Shamba+ — Farm Finance Made Simple</title>
<meta name="description" content="Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands.">
<meta property="og:title" content="Shamba+ — Farm Finance Made Simple">
<meta property="og:description" content="Track crops, livestock, income, and expenses in one place. Secure, simple farm record-keeping for Kenyan farmers.">
<meta property="og:image" content="https://shamba.samtama.lol/assets/hero.jpg">
<meta property="og:type" content="website">
<link rel="icon" href="/assets/logo.png">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<header class="nav">
  <div class="wrap nav-inner">
    <a class="brand" href="/#top">
      <img class="mark-img" src="/assets/logo.png" width="36" height="36" alt="">
      <span class="name">Shamba+</span>
    </a>
    <nav aria-label="Primary">
      <a href="#features">Features</a>
      <a href="/support/legal/privacy-policy.html">Privacy Policy</a>
      <a href="/support/legal/terms-of-service.html">Terms</a>
      <a href="/support/legal/delete-account.html">Delete Account</a>
    </nav>
  </div>
</header>

<main id="top">
  <section class="hero wrap">
    <h1>Shamba+</h1>
    <p class="tagline">Farm Finance Made Simple</p>
    <p class="lede">Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands, and can make confident decisions about what's next.</p>
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>

  <section id="features" class="features wrap">
    <div class="feature-card">
      <h2>Secure</h2>
      <p>Google Sign-In and encrypted storage keep your farm and financial records safe — only you can access them.</p>
    </div>
    <div class="feature-card">
      <h2>Grow</h2>
      <p>Track crops, livestock, income, and expenses in one place, and see clear trends as your farm grows.</p>
    </div>
    <div class="feature-card">
      <h2>Sustain</h2>
      <p>Simple, data-backed record-keeping that helps you make better decisions season after season.</p>
    </div>
  </section>
</main>

<footer class="site-footer">
  <div class="wrap footer-inner">
    <div class="brand">
      <img class="mark-img" src="/assets/logo.png" width="28" height="28" alt="">
      <span class="name">Shamba+</span>
    </div>
    <nav aria-label="Legal">
      <a href="/support/legal/privacy-policy.html">Privacy Policy</a>
      <a href="/support/legal/terms-of-service.html">Terms of Service</a>
      <a href="/support/legal/delete-account.html">Delete Account</a>
    </nav>
    <p class="copyright">© 2026 Shamba+ · SaMTama · <a href="mailto:ngigi.nyongo@gmail.com">ngigi.nyongo@gmail.com</a></p>
  </div>
</footer>
</body>
</html>
```

- [ ] **Step 3: Write the 404 page**

Create `docs/404.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Page Not Found — Shamba+</title>
<link rel="icon" href="/assets/logo.png">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<header class="nav">
  <div class="wrap nav-inner">
    <a class="brand" href="/">
      <img class="mark-img" src="/assets/logo.png" width="36" height="36" alt="">
      <span class="name">Shamba+</span>
    </a>
  </div>
</header>
<main>
  <section class="hero wrap">
    <h1>Page not found</h1>
    <p class="lede">The page you're looking for doesn't exist or may have moved. <a href="/">Go back to the Shamba+ home page</a>.</p>
  </section>
</main>
</body>
</html>
```

- [ ] **Step 4: Verify required content is present**

Run:
```bash
grep -q "<title>Shamba+ — Farm Finance Made Simple</title>" docs/index.html && echo "title OK"
grep -q 'href="/support/legal/privacy-policy.html"' docs/index.html && echo "privacy link OK"
grep -q 'href="/support/legal/terms-of-service.html"' docs/index.html && echo "terms link OK"
grep -q 'href="/support/legal/delete-account.html"' docs/index.html && echo "delete link OK"
grep -q 'id="features"' docs/index.html && echo "features anchor OK"
grep -q '<h1>Shamba+</h1>' docs/index.html && echo "h1 OK"
grep -q 'og:image' docs/index.html && echo "og:image OK"
grep -q 'Page not found' docs/404.html && echo "404 OK"
```
Expected: all eight "OK" lines print.

- [ ] **Step 5: Commit**

```bash
git add docs/index.html docs/404.html
git commit -m "feat: add Shamba+ landing page and 404 page"
```

---

### Task 4: Legal pages — contact email and back-link

**Files:**
- Modify: `docs/support/legal/privacy-policy.html`
- Modify: `docs/support/legal/privacy-policy.md`
- Modify: `docs/support/legal/terms-of-service.html`
- Modify: `docs/support/legal/terms-of-service.md`
- Modify: `docs/support/legal/delete-account.html`
- Modify: `docs/support/legal/style.css`

**Interfaces:**
- Consumes: existing `.wrap`, `.brand`, `.card` classes already in `docs/support/legal/style.css`.
- Produces: new `.back-link` class in `docs/support/legal/style.css`, used by the back-link markup added to all three `.html` files.

- [ ] **Step 1: Verify current state (should find old email, no back-link yet)**

Run:
```bash
grep -c "support@samtama.lol" docs/support/legal/privacy-policy.html docs/support/legal/privacy-policy.md docs/support/legal/terms-of-service.html docs/support/legal/terms-of-service.md docs/support/legal/delete-account.html
grep -c "back-link" docs/support/legal/*.html docs/support/legal/style.css
```
Expected: nonzero counts of `support@samtama.lol` (4, 4, 2, 3, 2 respectively); zero `back-link` matches anywhere.

- [ ] **Step 2: Add `.back-link` style**

In `docs/support/legal/style.css`, after the existing `.brand .name { ... }` block (currently lines 60-63), add:

```css
.back-link {
  margin: 0 0 20px;
  font-size: 0.9rem;
}
```

- [ ] **Step 3: Edit `privacy-policy.html`**

Replace:
```html
  <div class="brand"><div class="mark">S+</div><div class="name">Shamba+</div></div>
```
with:
```html
  <p class="back-link"><a href="/">← Back to Shamba+</a></p>
  <div class="brand"><div class="mark">S+</div><div class="name">Shamba+</div></div>
```

Then replace all four occurrences of `<a href="mailto:support@samtama.lol">support@samtama.lol</a>` with `<a href="mailto:ngigi.nyongo@gmail.com">ngigi.nyongo@gmail.com</a>` (lines 17, 47, 52, 61 — the link text and href both change).

- [ ] **Step 4: Edit `privacy-policy.md`**

Replace:
- Line 7: `**support@samtama.lol**` → `**ngigi.nyongo@gmail.com**`
- Line 40: `Emailing **support@samtama.lol**` → `Emailing **ngigi.nyongo@gmail.com**`
- Line 46: `contact **support@samtama.lol**` → `contact **ngigi.nyongo@gmail.com**`
- Line 59: `Email: support@samtama.lol` → `Email: ngigi.nyongo@gmail.com`

- [ ] **Step 5: Edit `terms-of-service.html`**

Replace:
```html
  <div class="brand"><div class="mark">S+</div><div class="name">Shamba+</div></div>
```
with:
```html
  <p class="back-link"><a href="/">← Back to Shamba+</a></p>
  <div class="brand"><div class="mark">S+</div><div class="name">Shamba+</div></div>
```

Then replace the two occurrences of `<a href="mailto:support@samtama.lol">support@samtama.lol</a>` with `<a href="mailto:ngigi.nyongo@gmail.com">ngigi.nyongo@gmail.com</a>` (lines 22, 43). Line 52 already reads `ngigi.nyongo@gmail.com` — leave it unchanged.

- [ ] **Step 6: Edit `terms-of-service.md`**

Replace:
- Line 13: `support@samtama.lol if you suspect` → `ngigi.nyongo@gmail.com if you suspect`
- Line 37: `emailing support@samtama.lol.` → `emailing ngigi.nyongo@gmail.com.`
- Line 50: `Email: support@samtama.lol` → `Email: ngigi.nyongo@gmail.com`

- [ ] **Step 7: Edit `delete-account.html`**

Replace:
```html
  <div class="brand"><div class="mark">S+</div><div class="name">Shamba+</div></div>
```
with:
```html
  <p class="back-link"><a href="/">← Back to Shamba+</a></p>
  <div class="brand"><div class="mark">S+</div><div class="name">Shamba+</div></div>
```

Replace:
```html
<a class="btn danger" href="mailto:support@samtama.lol?subject=Delete%20my%20Shamba%2B%20account&body=Please%20delete%20my%20Shamba%2B%20account%20and%20associated%20data.%20The%20email%20address%20on%20my%20account%20is%3A%20">Email support@samtama.lol</a>
```
with:
```html
<a class="btn danger" href="mailto:ngigi.nyongo@gmail.com?subject=Delete%20my%20Shamba%2B%20account&body=Please%20delete%20my%20Shamba%2B%20account%20and%20associated%20data.%20The%20email%20address%20on%20my%20account%20is%3A%20">Email ngigi.nyongo@gmail.com</a>
```

Replace:
```html
    <p>Questions? See our <a href="privacy-policy.html">Privacy Policy</a> or email <a href="mailto:support@samtama.lol">support@samtama.lol</a>.</p>
```
with:
```html
    <p>Questions? See our <a href="privacy-policy.html">Privacy Policy</a> or email <a href="mailto:ngigi.nyongo@gmail.com">ngigi.nyongo@gmail.com</a>.</p>
```

- [ ] **Step 8: Verify no old email remains and back-link is present on all three pages**

Run:
```bash
grep -rc "support@samtama.lol" docs/support/legal/ | grep -v ':0'
grep -c "back-link" docs/support/legal/privacy-policy.html docs/support/legal/terms-of-service.html docs/support/legal/delete-account.html
```
Expected: first command prints nothing (no remaining matches anywhere); second command prints `1` for each of the three files.

- [ ] **Step 9: Commit**

```bash
git add docs/support/legal/
git commit -m "fix: update legal pages contact email and add back-to-home link"
```

---

### Task 5: End-to-end verification

**Files:** none (verification only)

**Interfaces:**
- Consumes: all files produced by Tasks 1-4.
- Produces: nothing — this task only verifies the site holds together, then reports remaining manual steps.

- [ ] **Step 1: Serve the site locally**

```bash
python3 -m http.server 8000 --directory docs > /tmp/claude-1000/-home-ngigi-Documents-projects-farmTracker-frontend/*/scratchpad/docs-server.log 2>&1 &
sleep 1
```
(Use the actual scratchpad path for this session rather than the glob.)

- [ ] **Step 2: Check every internal link resolves**

```bash
for path in / /styles.css /assets/logo.png /assets/hero.jpg \
  /support/legal/privacy-policy.html /support/legal/terms-of-service.html \
  /support/legal/delete-account.html /support/legal/style.css; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000$path")
  echo "$path -> $code"
done
curl -s -o /dev/null -w "/nonexistent-page -> %{http_code}\n" http://localhost:8000/nonexistent-page
```
Expected: every real path returns `200`; `/nonexistent-page` returns `404` (Python's built-in server returns its own default 404 body here, not `docs/404.html` — that's expected locally; GitHub Pages serves the real `docs/404.html` in production, this step only confirms the status code and that no path 500s).

- [ ] **Step 3: Screenshot the rendered page**

```bash
chromium --headless --disable-gpu --window-size=1280,900 \
  --screenshot=/tmp/claude-1000/-home-ngigi-Documents-projects-farmTracker-frontend/*/scratchpad/landing-page.png \
  http://localhost:8000/
```
(Use the actual scratchpad path.) Then view the resulting PNG to confirm: hero image renders, nav links are visible, feature cards are laid out in a row (or stacked, depending on viewport), no broken image icons.

- [ ] **Step 4: Stop the local server**

```bash
kill %1 2>/dev/null || pkill -f "http.server 8000"
```

- [ ] **Step 5: Report remaining manual steps to the user**

These cannot be done by an agent — they require access to Cloudflare, GitHub repo settings, and Google Cloud Console:
1. Push this branch/commits to `origin/main`.
2. Wait for GitHub Pages to detect `docs/CNAME` and show `shamba.samtama.lol` as verified under repo Settings → Pages, then enable "Enforce HTTPS" once available.
3. In Google Cloud Console → OAuth consent screen → Branding, update: Application home page → `https://shamba.samtama.lol/`; Privacy policy link → `https://shamba.samtama.lol/support/legal/privacy-policy.html`; Terms of service link → `https://shamba.samtama.lol/support/legal/terms-of-service.html`.
4. Re-submit for OAuth verification.

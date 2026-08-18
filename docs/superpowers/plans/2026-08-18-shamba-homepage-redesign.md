# Shamba+ Homepage Redesign & SEO Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `docs/index.html` (the live site at `https://shamba.samtama.lol/`) with more content, a richer visual system borrowed from the `pet_store` reference project, and SEO/meta parity with `https://portfolio.samtama.lol`, so the page more clearly explains Shamba+'s purpose before the next OAuth consent screen re-scrape.

**Architecture:** Single static page (`docs/index.html` + `docs/styles.css`), no build step, no JS. Work proceeds head-first (SEO/meta, fonts), then CSS foundations, then one HTML section at a time in document order (nav → hero → trust strip → about → how it works → features → who it's for → footer), so each task is independently visible and testable against a locally-served copy of `docs/`.

**Tech Stack:** Plain HTML5 + CSS (custom properties, `prefers-color-scheme`), inline SVG icons, Google Fonts (Fraunces + Work Sans). Verification uses `python3 -m http.server`, `curl`, `grep`, `python3 -m json.tool` / `xml.dom.minidom`, and headless `chromium` screenshots.

## Global Constraints

- No JS framework, build step, or client-side interactivity — plain static HTML/CSS only, inline SVG icons (spec: Non-goals).
- Retain all existing copy verbatim: Hero `<h1>`/tagline/lede, About's two paragraphs, the Secure/Grow/Sustain descriptions (spec: Goals, Page structure).
- No Play Store badge/CTA — app is still in closed testing (spec: Non-goals).
- No fabricated social proof — no user counts, ratings, or testimonials (spec: Non-goals, Trust strip).
- No changes to `docs/support/legal/*` content or styling (spec: Non-goals).
- Font pairing: Google Fonts **Fraunces** (headings) + **Work Sans** (body), loaded with `preconnect` + `display=swap` (spec: Visual system).
- Existing color tokens (`--bg`, `--surface`, `--text`, `--muted`, `--accent`, `--border`, `--danger`) stay unchanged; only new addition is `--accent-soft` (spec: Visual system).
- JSON-LD must not include `aggregateRating` or `offers` (spec: SEO / meta).

---

### Task 1: Head upgrade — SEO meta, Open Graph, Twitter Card, JSON-LD, font links

**Files:**
- Modify: `docs/index.html` (`<head>` block only)

**Interfaces:**
- Produces: `<link>` tags for Fraunces/Work Sans (consumed by Task 3's CSS `font-family` rules); `theme-color` values `#f7f5f0` (light) / `#14170f` (dark) matching existing `--bg` tokens.

- [ ] **Step 1: Replace the `<head>` block**

Replace the entire existing `<head>...</head>` block in `docs/index.html` with:

```html
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Shamba+ — Farm Finance Made Simple</title>
<meta name="description" content="Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands.">
<meta name="robots" content="index, follow">
<link rel="canonical" href="https://shamba.samtama.lol/">
<meta property="og:title" content="Shamba+ — Farm Finance Made Simple">
<meta property="og:description" content="Track crops, livestock, income, and expenses in one place. Secure, simple farm record-keeping for Kenyan farmers.">
<meta property="og:image" content="https://shamba.samtama.lol/assets/hero.jpg">
<meta property="og:image:type" content="image/jpeg">
<meta property="og:image:width" content="1168">
<meta property="og:image:height" content="784">
<meta property="og:image:alt" content="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
<meta property="og:type" content="website">
<meta property="og:url" content="https://shamba.samtama.lol/">
<meta property="og:site_name" content="Shamba+">
<meta property="og:locale" content="en_KE">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="Shamba+ — Farm Finance Made Simple">
<meta name="twitter:description" content="Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands.">
<meta name="twitter:image" content="https://shamba.samtama.lol/assets/hero.jpg">
<meta name="twitter:image:alt" content="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
<meta name="theme-color" content="#f7f5f0" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#14170f" media="(prefers-color-scheme: dark)">
<link rel="icon" href="/assets/logo.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600;9..144,700&family=Work+Sans:wght@400;500;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/styles.css">
<script type="application/ld+json">
[
  {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "name": "Shamba+",
    "url": "https://shamba.samtama.lol/"
  },
  {
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    "name": "Shamba+",
    "description": "Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands.",
    "url": "https://shamba.samtama.lol/",
    "operatingSystem": "Android",
    "applicationCategory": "FinanceApplication",
    "inLanguage": "en",
    "author": {
      "@type": "Organization",
      "name": "SaMTama"
    }
  }
]
</script>
</head>
```

- [ ] **Step 2: Verify the head tags and JSON-LD**

```bash
grep -c 'name="robots"' docs/index.html
grep -c 'rel="canonical"' docs/index.html
grep -c 'twitter:card' docs/index.html
grep -c 'fonts.googleapis.com/css2' docs/index.html
```

Expected: each command prints `1`.

Then validate the JSON-LD block is well-formed JSON:

```bash
python3 -c "
import re, json
html = open('docs/index.html').read()
m = re.search(r'<script type=\"application/ld\+json\">(.*?)</script>', html, re.S)
json.loads(m.group(1))
print('JSON-LD valid')
"
```

Expected: `JSON-LD valid`.

- [ ] **Step 3: Commit**

```bash
git add docs/index.html
git commit -m "feat(landing): expand SEO meta, add JSON-LD and font preconnects"
```

---

### Task 2: `robots.txt` and `sitemap.xml`

**Files:**
- Create: `docs/robots.txt`
- Create: `docs/sitemap.xml`

**Interfaces:**
- Produces: `https://shamba.samtama.lol/robots.txt`, `https://shamba.samtama.lol/sitemap.xml` (no other task depends on these).

- [ ] **Step 1: Create `docs/robots.txt`**

```
User-agent: *
Allow: /

Sitemap: https://shamba.samtama.lol/sitemap.xml
```

- [ ] **Step 2: Create `docs/sitemap.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://shamba.samtama.lol/</loc>
  </url>
  <url>
    <loc>https://shamba.samtama.lol/support/legal/privacy-policy.html</loc>
  </url>
  <url>
    <loc>https://shamba.samtama.lol/support/legal/terms-of-service.html</loc>
  </url>
  <url>
    <loc>https://shamba.samtama.lol/support/legal/delete-account.html</loc>
  </url>
</urlset>
```

- [ ] **Step 3: Verify both files**

```bash
cat docs/robots.txt
python3 -c "import xml.dom.minidom as m; m.parse('docs/sitemap.xml'); print('sitemap.xml valid')"
```

Expected: `robots.txt` contents print as written; `sitemap.xml valid` prints with no error.

- [ ] **Step 4: Commit**

```bash
git add docs/robots.txt docs/sitemap.xml
git commit -m "feat(landing): add robots.txt and sitemap.xml"
```

---

### Task 3: CSS foundations — fonts, `--accent-soft`, badges, buttons, section headers, icon badges

**Files:**
- Modify: `docs/styles.css`

**Interfaces:**
- Consumes: existing `--bg`/`--surface`/`--text`/`--muted`/`--accent`/`--border` tokens; Fraunces/Work Sans `<link>` tags from Task 1.
- Produces (classes every later HTML task relies on): `.badge`, `.hero-actions`, `.btn`, `.btn-primary`, `.btn-outline`, `.icon-badge`, `.section-header`, and the new `--accent-soft` custom property.

- [ ] **Step 1: Add `--accent-soft` to both color-scheme blocks**

In `docs/styles.css`, change:

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
```

to:

```css
:root {
  --bg: #f7f5f0;
  --surface: #ffffff;
  --text: #23291f;
  --muted: #5b6357;
  --accent: #2e7d32;
  --accent-soft: rgba(46, 125, 50, 0.12);
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
    --accent-soft: rgba(111, 207, 115, 0.16);
    --border: #2c3223;
    --danger: #ef5350;
  }
}
```

- [ ] **Step 2: Apply the Fraunces/Work Sans font pairing**

Change:

```css
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.6;
}
```

to:

```css
body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: "Work Sans", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.6;
}

h1, h2, h3 {
  font-family: "Fraunces", Georgia, "Times New Roman", serif;
  font-weight: 600;
}
```

- [ ] **Step 3: Add badge, button, icon-badge, and section-header rules**

Append to the end of `docs/styles.css` (after the existing `.copyright` rule):

```css

/* Badge */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  border-radius: 999px;
  background: var(--accent-soft);
  color: var(--accent);
  font-size: 0.8rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  margin-bottom: 16px;
}

.badge svg { flex-shrink: 0; }

/* Buttons */
.hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  justify-content: center;
  margin-bottom: 36px;
}

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 12px 24px;
  border-radius: 999px;
  font-weight: 600;
  font-size: 0.95rem;
  text-decoration: none;
  border: 1px solid transparent;
  cursor: pointer;
}

.btn-primary {
  background: var(--accent);
  color: var(--surface);
}

.btn-outline {
  background: transparent;
  border-color: var(--border);
  color: var(--text);
}

/* Icon badge (used inside feature/step cards) */
.icon-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--accent-soft);
  color: var(--accent);
  margin-bottom: 12px;
}

.icon-badge svg { display: block; }

/* Section header (used by How It Works / Features / Who It's For) */
.section-header {
  text-align: center;
  max-width: 640px;
  margin: 0 auto 32px;
}

.section-header h2 {
  margin: 0 0 8px;
  font-size: clamp(1.5rem, 3vw, 2rem);
}

.section-header p {
  margin: 0;
  color: var(--muted);
}
```

- [ ] **Step 4: Verify**

```bash
grep -c '\-\-accent-soft' docs/styles.css
grep -c '\.btn-primary' docs/styles.css
grep -c '\.section-header' docs/styles.css
```

Expected: `--accent-soft` prints `4` (2 `:root`/dark definitions + 2 usages inside the new `.badge`/`.icon-badge` rules just added); `.btn-primary` prints `1` (only the definition — HTML that uses this class isn't added until Task 5); `.section-header` prints `3` (the base rule plus its `h2` and `p` sub-selectors).

- [ ] **Step 5: Commit**

```bash
git add docs/styles.css
git commit -m "feat(landing): add font pairing, accent-soft token, and shared badge/button/section-header styles"
```

---

### Task 4: Nav restructure — content anchors replace legal links

**Files:**
- Modify: `docs/index.html` (`<header class="nav">` block)

**Interfaces:**
- Consumes: none new.
- Produces: nav links to `#about`, `#how-it-works`, `#features`, `#who-its-for` — the last three anchors don't exist yet (created in Tasks 7, 8, 9) but the nav is safe to ship first since a non-matching in-page anchor just does nothing until the target exists.

- [ ] **Step 1: Replace the nav links**

Change:

```html
    <nav aria-label="Primary">
      <a href="#about">About</a>
      <a href="#features">Features</a>
      <a href="/support/legal/privacy-policy.html">Privacy Policy</a>
      <a href="/support/legal/terms-of-service.html">Terms</a>
      <a href="/support/legal/delete-account.html">Delete Account</a>
    </nav>
```

to:

```html
    <nav aria-label="Primary">
      <a href="#about">About</a>
      <a href="#how-it-works">How It Works</a>
      <a href="#features">Features</a>
      <a href="#who-its-for">Who It's For</a>
    </nav>
```

- [ ] **Step 2: Verify**

```bash
grep -c 'href="#who-its-for"' docs/index.html
grep -c 'href="/support/legal/privacy-policy.html"' docs/index.html
```

Expected: first prints `1`; second prints `0` (the legal link moves to the footer in Task 10, not removed from the page entirely).

- [ ] **Step 3: Commit**

```bash
git add docs/index.html
git commit -m "feat(landing): simplify nav to content anchors, move legal links to footer"
```

---

### Task 5: Hero badge and CTA buttons

**Files:**
- Modify: `docs/index.html` (`<section class="hero wrap">` block)

**Interfaces:**
- Consumes: `.badge`, `.hero-actions`, `.btn`, `.btn-primary`, `.btn-outline` from Task 3.

- [ ] **Step 1: Add the badge and CTA buttons to the hero**

Change:

```html
  <section class="hero wrap">
    <h1>Shamba+</h1>
    <p class="tagline">Farm Finance Made Simple</p>
    <p class="lede">Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands, and can make confident decisions about what's next.</p>
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>
```

to:

```html
  <section class="hero wrap">
    <span class="badge">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
      Built for Kenyan Farmers
    </span>
    <h1>Shamba+</h1>
    <p class="tagline">Farm Finance Made Simple</p>
    <p class="lede">Shamba+ helps Kenyan farmers track crops, livestock, income, and expenses in one place — so you always know where your farm stands, and can make confident decisions about what's next.</p>
    <div class="hero-actions">
      <a href="#how-it-works" class="btn btn-primary">How It Works</a>
      <a href="#about" class="btn btn-outline">About Shamba+</a>
    </div>
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>
```

- [ ] **Step 2: Verify**

```bash
grep -c 'Built for Kenyan Farmers' docs/index.html
grep -c 'class="hero-actions"' docs/index.html
```

Expected: both print `1`.

- [ ] **Step 3: Commit**

```bash
git add docs/index.html
git commit -m "feat(landing): add hero badge and CTA buttons"
```

---

### Task 6: Trust strip section

**Files:**
- Modify: `docs/index.html` (insert between the closing `</section>` of hero and the opening `<section id="about"...>`)
- Modify: `docs/styles.css` (append trust-strip rules)

**Interfaces:**
- Produces: `.trust-strip`, `.trust-items`, `.trust-item` CSS classes (used only here).

- [ ] **Step 1: Insert the trust strip markup**

Change:

```html
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>

  <section id="about" class="about wrap">
```

to:

```html
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>

  <div class="trust-strip" role="region" aria-label="Trust signals">
    <div class="wrap">
      <ul class="trust-items">
        <li class="trust-item">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          Google Secure Sign-In
        </li>
        <li class="trust-item">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>
          Crops, livestock & finances — one place
        </li>
        <li class="trust-item">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>
          Encrypted, private records
        </li>
        <li class="trust-item">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
          Built for Kenyan smallholder farms
        </li>
      </ul>
    </div>
  </div>

  <section id="about" class="about wrap">
```

- [ ] **Step 2: Add trust-strip CSS**

Append to `docs/styles.css`:

```css

/* Trust strip */
.trust-strip {
  border-top: 1px solid var(--border);
  border-bottom: 1px solid var(--border);
  padding: 20px 0;
}

.trust-items {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 20px 32px;
}

.trust-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.9rem;
  color: var(--muted);
}

.trust-item svg {
  color: var(--accent);
  flex-shrink: 0;
}
```

- [ ] **Step 3: Verify**

```bash
grep -c 'class="trust-strip"' docs/index.html
grep -c '<li class="trust-item">' docs/index.html
```

Expected: first prints `1`, second prints `4`.

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/styles.css
git commit -m "feat(landing): add trust strip section"
```

---

### Task 7: "How it works" section

**Files:**
- Modify: `docs/index.html` (insert between the closing `</section>` of About and the opening `<section id="features"...>`)
- Modify: `docs/styles.css` (append `.steps`/`.step-card`/`.step-number` rules)

**Interfaces:**
- Consumes: `.section-header`, `.icon-badge` from Task 3.
- Produces: `#how-it-works` anchor target (nav link from Task 4 now resolves); `.steps`, `.step-card`, `.step-number` CSS classes.

- [ ] **Step 1: Insert the "How it works" section**

Change:

```html
  </section>

  <section id="features" class="features wrap">
```

to:

```html
  </section>

  <section id="how-it-works" class="wrap">
    <div class="section-header">
      <h2>How Shamba+ works</h2>
      <p>From sign-in to season-end numbers, in four steps.</p>
    </div>
    <div class="steps">
      <div class="step-card">
        <span class="step-number">1</span>
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
        </div>
        <h3>Sign in with Google</h3>
        <p>One tap, no new password to create or remember.</p>
      </div>
      <div class="step-card">
        <span class="step-number">2</span>
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"/><line x1="8" y1="2" x2="8" y2="18"/><line x1="16" y1="6" x2="16" y2="22"/></svg>
        </div>
        <h3>Set up your farm</h3>
        <p>Add your land, crops, seasons, and livestock.</p>
      </div>
      <div class="step-card">
        <span class="step-number">3</span>
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="4" y1="20" x2="16" y2="8"/><polygon points="15 7 17 5 20 8 18 10"/><line x1="4" y1="20" x2="7" y2="19"/></svg>
        </div>
        <h3>Log as you go</h3>
        <p>Record costs, inputs, harvests, and revenue as they happen.</p>
      </div>
      <div class="step-card">
        <span class="step-number">4</span>
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>
        </div>
        <h3>See the full picture</h3>
        <p>Track trends across seasons and know exactly where your farm stands.</p>
      </div>
    </div>
  </section>

  <section id="features" class="features wrap">
```

- [ ] **Step 2: Add "How it works" CSS**

Append to `docs/styles.css`:

```css

/* How it works */
#how-it-works {
  padding: 48px 0 64px;
}

.steps {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 20px;
}

.step-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 24px;
  position: relative;
}

.step-number {
  position: absolute;
  top: 20px;
  right: 20px;
  font-family: "Fraunces", serif;
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--border);
}

.step-card h3 {
  margin: 0 0 8px;
  font-size: 1.05rem;
}

.step-card p {
  margin: 0;
  color: var(--muted);
  font-size: 0.9rem;
}
```

- [ ] **Step 3: Verify**

```bash
grep -c 'id="how-it-works"' docs/index.html
grep -c 'class="step-card"' docs/index.html
```

Expected: first prints `1`, second prints `4`.

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/styles.css
git commit -m "feat(landing): add How It Works section"
```

---

### Task 8: Features section restructure (section header, `h3` cards, icons)

**Files:**
- Modify: `docs/index.html` (`<section id="features"...>` block)
- Modify: `docs/styles.css` (`.features` and `.feature-card h2` rules)

**Interfaces:**
- Consumes: `.section-header`, `.icon-badge` from Task 3.
- Produces: card headings change from `<h2>` to `<h3>` (About's `<h2>` and the new section `<h2>`s are now the only `<h2>`s after Hero's `<h1>`, keeping heading hierarchy correct).

- [ ] **Step 1: Restructure the Features section markup**

Change:

```html
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
```

to:

```html
  <section id="features" class="wrap">
    <div class="section-header">
      <h2>Why Shamba+</h2>
    </div>
    <div class="features">
      <div class="feature-card">
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
        </div>
        <h3>Secure</h3>
        <p>Google Sign-In and encrypted storage keep your farm and financial records safe — only you can access them.</p>
      </div>
      <div class="feature-card">
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>
        </div>
        <h3>Grow</h3>
        <p>Track crops, livestock, income, and expenses in one place, and see clear trends as your farm grows.</p>
      </div>
      <div class="feature-card">
        <div class="icon-badge">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 21 L12 11"/><path d="M12 11 L6 5 L4 9 L8 13 Z"/><path d="M12 11 L18 6 L20 10 L15 14 Z"/></svg>
        </div>
        <h3>Sustain</h3>
        <p>Simple, data-backed record-keeping that helps you make better decisions season after season.</p>
      </div>
    </div>
  </section>
```

- [ ] **Step 2: Update the Features CSS**

Change:

```css
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
```

to:

```css
/* Features */
#features {
  padding: 48px 0 64px;
}

.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 20px;
}

.feature-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 28px 24px;
}

.feature-card h3 {
  margin: 0 0 8px;
  font-size: 1.15rem;
  color: var(--accent);
}

.feature-card p {
  margin: 0;
  color: var(--text);
}
```

- [ ] **Step 3: Verify**

```bash
grep -c '<h3>Secure</h3>' docs/index.html
grep -c '<h2>Secure</h2>' docs/index.html
grep -c 'id="features" class="wrap"' docs/index.html
```

Expected: first prints `1`, second prints `0`, third prints `1`.

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/styles.css
git commit -m "feat(landing): restructure Features section with header and icons"
```

---

### Task 9: "Who it's for" section

**Files:**
- Modify: `docs/index.html` (insert between the closing `</section>` of Features and the closing `</main>`)
- Modify: `docs/styles.css` (append `.chip-list`/`.chip` rules)

**Interfaces:**
- Consumes: `.section-header` from Task 3.
- Produces: `#who-its-for` anchor target (nav link from Task 4 now resolves).

- [ ] **Step 1: Insert the "Who it's for" section**

Change:

```html
    </div>
  </section>
</main>
```

to:

```html
    </div>
  </section>

  <section id="who-its-for" class="wrap">
    <div class="section-header">
      <h2>Who Shamba+ is for</h2>
    </div>
    <p>Shamba+ is built for Kenyan smallholder farmers — whether you grow crops, keep livestock, or run a mixed operation — who are ready to trade paper notebooks and guesswork for a clear, always-current record of how their farm is really doing.</p>
    <ul class="chip-list">
      <li class="chip">Crop farmers</li>
      <li class="chip">Livestock keepers</li>
      <li class="chip">Mixed farms</li>
      <li class="chip">Family-run smallholdings</li>
    </ul>
  </section>
</main>
```

- [ ] **Step 2: Add "Who it's for" CSS**

Append to `docs/styles.css`:

```css

/* Who it's for */
#who-its-for {
  padding: 0 0 64px;
  text-align: center;
}

#who-its-for > p {
  max-width: 640px;
  margin: 0 auto 24px;
  color: var(--muted);
}

.chip-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 10px;
}

.chip {
  background: var(--accent-soft);
  color: var(--accent);
  border-radius: 999px;
  padding: 8px 16px;
  font-size: 0.85rem;
  font-weight: 600;
}
```

- [ ] **Step 3: Verify**

```bash
grep -c 'id="who-its-for"' docs/index.html
grep -c 'class="chip"' docs/index.html
```

Expected: first prints `1`, second prints `4`.

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/styles.css
git commit -m "feat(landing): add Who It's For section"
```

---

### Task 10: Footer restructure — logo, legal nav, copyright

**Files:**
- Modify: `docs/index.html` (`<footer class="site-footer">` block)
- Modify: `docs/styles.css` (`.footer-inner`/`.copyright` rules)

**Interfaces:**
- Consumes: `.brand`, `.mark-img`, `.name` (existing nav classes, reused as-is).
- Produces: `.footer-nav` CSS class.

- [ ] **Step 1: Restructure the footer markup**

Change:

```html
<footer class="site-footer">
  <div class="wrap footer-inner">
    <p class="copyright">© 2026 Shamba+</p>
  </div>
</footer>
```

to:

```html
<footer class="site-footer">
  <div class="wrap footer-inner">
    <a class="brand" href="/#top">
      <img class="mark-img" src="/assets/logo.png" width="28" height="28" alt="">
      <span class="name">Shamba+</span>
    </a>
    <nav class="footer-nav" aria-label="Legal">
      <a href="/support/legal/privacy-policy.html">Privacy Policy</a>
      <a href="/support/legal/terms-of-service.html">Terms of Service</a>
      <a href="/support/legal/delete-account.html">Delete Account</a>
    </nav>
    <p class="copyright">© 2026 Shamba+</p>
  </div>
</footer>
```

- [ ] **Step 2: Update the footer CSS**

Change:

```css
/* Footer */
.site-footer {
  border-top: 1px solid var(--border);
  margin-top: 20px;
}

.footer-inner {
  padding: 32px 20px;
  text-align: center;
}

.copyright {
  color: var(--muted);
  font-size: 0.85rem;
  margin: 0;
}
```

to:

```css
/* Footer */
.site-footer {
  border-top: 1px solid var(--border);
  margin-top: 20px;
}

.footer-inner {
  padding: 32px 20px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  text-align: center;
}

.footer-inner .name {
  font-size: 15px;
}

.footer-nav {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 20px;
}

.footer-nav a {
  color: var(--muted);
  text-decoration: none;
  font-size: 0.85rem;
}

.footer-nav a:hover { color: var(--accent); }

.copyright {
  color: var(--muted);
  font-size: 0.8rem;
  margin: 0;
}
```

- [ ] **Step 3: Verify**

```bash
grep -c 'class="footer-nav"' docs/index.html
grep -c 'href="/support/legal/delete-account.html"' docs/index.html
```

Expected: first prints `1`, second prints `1`.

- [ ] **Step 4: Commit**

```bash
git add docs/index.html docs/styles.css
git commit -m "feat(landing): restructure footer with logo and legal nav"
```

---

### Task 11: Full-page integration verification

**Files:** none (verification only — no code changes expected; if this task finds a problem, fix it in the relevant file and commit the fix before proceeding)

**Interfaces:** none.

- [ ] **Step 1: Structural sanity checks**

```bash
grep -c '<h1>' docs/index.html
for anchor in about how-it-works features who-its-for; do
  echo -n "#$anchor -> "
  grep -c "id=\"$anchor\"" docs/index.html
done
```

Expected: `<h1>` count is `1`; each anchor ID count is `1`.

- [ ] **Step 2: Serve locally and confirm the page loads with all sections**

```bash
python3 -m http.server 8765 --directory docs &
SERVER_PID=$!
sleep 1
curl -s http://localhost:8765/ | grep -o '<h2>[^<]*</h2>'
kill $SERVER_PID
```

Expected output (order matters): `<h2>About Shamba+</h2>`, `<h2>How Shamba+ works</h2>`, `<h2>Why Shamba+</h2>`, `<h2>Who Shamba+ is for</h2>`.

- [ ] **Step 3: Screenshot light and dark mode**

```bash
python3 -m http.server 8765 --directory docs &
SERVER_PID=$!
sleep 1
chromium --headless --disable-gpu --screenshot=/tmp/shamba-light.png --window-size=1280,3200 --blink-settings=preferredColorScheme=1 http://localhost:8765/
chromium --headless --disable-gpu --screenshot=/tmp/shamba-dark.png --window-size=1280,3200 --blink-settings=preferredColorScheme=2 http://localhost:8765/
kill $SERVER_PID
```

Then view `/tmp/shamba-light.png` and `/tmp/shamba-dark.png` (Read tool, or open in an image viewer) and confirm: fonts render as serif headings / sans body, all eight sections are present in order, icons render (not broken/missing), no layout overlap, dark mode colors match the existing green-on-dark palette.

- [ ] **Step 4: Fix any issues found**

If Step 3 reveals a visual problem, fix it in `docs/index.html` or `docs/styles.css`, re-run Steps 2–3, and commit the fix with a message describing what was wrong (e.g. `git commit -m "fix(landing): correct icon-badge alignment in step cards"`).

- [ ] **Step 5: Report final state (no push)**

Run `git log --oneline -12` and `git status` to confirm all ten prior tasks are committed and the working tree is clean. Do **not** push — pushing `main` updates the live GitHub Pages site, and per the spec's verification plan, the developer should review the rendered page before it goes live and before re-running OAuth verification.

# Landing Page About Section & Footer Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "About Shamba+" section to the landing page and simplify the footer to a single copyright line, so the home page more clearly explains the app's purpose ahead of retrying Google OAuth verification.

**Architecture:** Direct extension of the existing plain HTML/CSS landing page — new CSS rules in `docs/styles.css`, new markup and a trimmed footer in `docs/index.html`. No new files, no build step.

**Tech Stack:** Static HTML5 + CSS3, same as the rest of `docs/`.

## Global Constraints

- No JS. Plain HTML/CSS only, matching the rest of `docs/`.
- Color tokens must come from the existing `:root` custom properties in `docs/styles.css` (`--bg`, `--surface`, `--text`, `--muted`, `--accent`, `--border`) — no new hardcoded colors.
- The About card must visually match the existing `.feature-card` treatment (surface background, border, 16px radius) for consistency.
- Footer becomes exactly one line: `© 2026 Shamba+`. No logo, no nav, no email in the footer — those stay reachable via the top nav only.
- Nav order becomes: About, Features, Privacy Policy, Terms, Delete Account.

---

### Task 1: Stylesheet — About section and simplified footer rules

**Files:**
- Modify: `docs/styles.css`

**Interfaces:**
- Consumes: existing `:root` color custom properties, existing `.wrap` and `.feature-card` patterns as visual reference.
- Produces: `.about`, `.about-card`, `.about-card h2`, `.about-card p` classes (consumed by Task 2's HTML). Modifies `.footer-inner` and `.copyright`; removes `.footer-inner .mark-img`, `.site-footer nav`, `.site-footer nav a`, `.site-footer nav a:hover`, `.copyright a` (all become dead code once the footer no longer has a logo, nav, or link).

- [ ] **Step 1: Verify current footer CSS block (to be replaced) is present**

Run: `grep -n "footer-inner .mark-img\|site-footer nav\|copyright a" docs/styles.css`
Expected: 4 matching lines (the rules about to be removed).

- [ ] **Step 2: Add the About section styles**

In `docs/styles.css`, insert immediately before the `/* Footer */` comment (currently line 153):

```css
/* About */
.about {
  padding: 0 20px 40px;
}

.about-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 36px clamp(20px, 5vw, 48px);
  max-width: 700px;
  margin: 0 auto;
  text-align: center;
}

.about-card h2 {
  margin: 0 0 16px;
  font-size: 1.3rem;
  color: var(--accent);
}

.about-card p {
  margin: 0 0 16px;
  color: var(--text);
}

.about-card p:last-child { margin-bottom: 0; }

```

- [ ] **Step 3: Simplify the footer rules**

Replace this block:

```css
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

with:

```css
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

- [ ] **Step 4: Verify braces are balanced and dead rules are gone**

Run: `grep -o "{" docs/styles.css | wc -l && grep -o "}" docs/styles.css | wc -l`
Expected: the two numbers are equal (don't hardcode a number — just confirm they match; a mismatch means a syntax slip).

Run: `grep -c "footer-inner .mark-img\|site-footer nav\|copyright a" docs/styles.css`
Expected: `0`

- [ ] **Step 5: Commit**

```bash
git add docs/styles.css
git commit -m "feat: add About section styles and simplify footer styling"
```

---

### Task 2: Landing page markup — nav, About section, trimmed footer

**Files:**
- Modify: `docs/index.html`

**Interfaces:**
- Consumes: `.about`, `.about-card` classes from Task 1.
- Produces: `#about` anchor target, consumed by the new nav link and any future internal links.

- [ ] **Step 1: Verify current state (no About section, old footer, old nav)**

Run: `grep -c 'id="about"\|href="#about"' docs/index.html && grep -c 'class="footer-inner"><div class="brand"' docs/index.html`
Expected: `0` for the first (About doesn't exist yet); the second grep can be run as `grep -A2 'wrap footer-inner' docs/index.html` — expected output shows the current `<div class="brand">` still there (confirms we're editing the old version).

- [ ] **Step 2: Add "About" to the nav**

Replace:

```html
    <nav aria-label="Primary">
      <a href="#features">Features</a>
      <a href="/support/legal/privacy-policy.html">Privacy Policy</a>
      <a href="/support/legal/terms-of-service.html">Terms</a>
      <a href="/support/legal/delete-account.html">Delete Account</a>
    </nav>
```

with:

```html
    <nav aria-label="Primary">
      <a href="#about">About</a>
      <a href="#features">Features</a>
      <a href="/support/legal/privacy-policy.html">Privacy Policy</a>
      <a href="/support/legal/terms-of-service.html">Terms</a>
      <a href="/support/legal/delete-account.html">Delete Account</a>
    </nav>
```

- [ ] **Step 3: Insert the About section between Hero and Features**

Replace:

```html
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>

  <section id="features" class="features wrap">
```

with:

```html
    <img class="hero-image" src="/assets/hero.jpg" width="1168" height="784" alt="Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain.">
  </section>

  <section id="about" class="about wrap">
    <div class="about-card">
      <h2>About Shamba+</h2>
      <p>Most smallholder farms in Kenya run on paper notebooks, memory, and guesswork — it's hard to know whether a season was actually profitable, which crop or herd is pulling its weight, or where money is really going until it's too late to change course.</p>
      <p>Shamba+ brings your farm's records into one place: land, crops, seasons and harvests; animals, herds, and their activity; every cost, input, and revenue entry. Instead of scattered notebooks, you get a clear, always-up-to-date picture of your farm's finances — so you can spot what's working, plan the next season with real numbers, and make decisions with confidence instead of guesswork.</p>
    </div>
  </section>

  <section id="features" class="features wrap">
```

- [ ] **Step 4: Simplify the footer**

Replace:

```html
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
```

with:

```html
<footer class="site-footer">
  <div class="wrap footer-inner">
    <p class="copyright">© 2026 Shamba+</p>
  </div>
</footer>
```

- [ ] **Step 5: Verify required content is present**

Run:
```bash
grep -q 'href="#about"' docs/index.html && echo "nav about link OK"
grep -q 'id="about"' docs/index.html && echo "about anchor OK"
grep -q '<h2>About Shamba+</h2>' docs/index.html && echo "about heading OK"
grep -q 'Most smallholder farms in Kenya' docs/index.html && echo "about paragraph 1 OK"
grep -q 'Shamba+ brings your farm' docs/index.html && echo "about paragraph 2 OK"
grep -c 'support/legal' docs/index.html
grep -q '<p class="copyright">© 2026 Shamba+</p>' docs/index.html && echo "footer OK"
grep -c 'mailto:ngigi.nyongo@gmail.com' docs/index.html
```
Expected: all five "OK" echoes print for the about section; the `support/legal` count is `3` (the three nav links only — footer no longer duplicates them); footer OK prints; the final `mailto:ngigi.nyongo@gmail.com` count is `0` (the footer's email line is fully removed, not just restyled).

- [ ] **Step 6: Commit**

```bash
git add docs/index.html
git commit -m "feat: add About section and simplify footer on landing page"
```

---

### Task 3: End-to-end verification and deploy

**Files:** none (verification and push only)

**Interfaces:**
- Consumes: all changes from Tasks 1-2.
- Produces: nothing — pushes the result live for the user to retry OAuth verification against.

- [ ] **Step 1: Serve the site locally**

```bash
python3 -m http.server 8000 --directory docs > /tmp/claude-1000/-home-ngigi-Documents-projects-farmTracker-frontend/b140b279-ea28-4391-9eaa-6253f1fef793/scratchpad/docs-server-2.log 2>&1 &
sleep 1
curl -s -o /dev/null -w "status: %{http_code}\n" http://localhost:8000/
```
Expected: `status: 200`

- [ ] **Step 2: Screenshot the rendered page (tall viewport to capture all sections)**

```bash
chromium --headless --disable-gpu --window-size=1280,2200 \
  --screenshot=/tmp/claude-1000/-home-ngigi-Documents-projects-farmTracker-frontend/b140b279-ea28-4391-9eaa-6253f1fef793/scratchpad/landing-page-about.png \
  http://localhost:8000/
```
Then view the PNG and confirm: nav shows About/Features/Privacy Policy/Terms/Delete Account in that order; About card renders between Hero and Features with both paragraphs; footer shows only "© 2026 Shamba+" with no logo/links.

- [ ] **Step 3: Stop the local server**

```bash
pkill -f "http.server 8000"
```

- [ ] **Step 4: Push**

```bash
git push origin main
```

- [ ] **Step 5: Report to the user**

Tell the user the page is live at `https://shamba.samtama.lol/` with the new About section and simplified footer, and that they can now retry the OAuth branding verification.

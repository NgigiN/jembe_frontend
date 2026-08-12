# Shamba+ Landing Page — Design

## Motivation

Google's OAuth consent screen verification flagged four issues (screenshot,
2026-08-12):

1. Home page (`https://portfolio.samtama.lol/projects/farm-tracker`) has no
   link to the privacy policy.
2. The privacy policy URL (`https://ngigin.github.io/jembe_frontend/...`) is
   on `github.io`, which Google does not accept as a "qualified domain" for
   verification.
3. The home page doesn't explain the app's purpose.
4. The OAuth consent screen app name ("Shamba+") doesn't match the app name
   shown on the home page.

All four are fixed by building a real Shamba+ landing page and hosting it
(along with the existing legal pages) on a domain the developer owns —
`samtama.lol` — instead of `github.io` or the unrelated portfolio site.

## Goals

- A single static landing page at `https://shamba.samtama.lol/` that names
  and explains Shamba+, and links to its legal pages.
- Legal pages (`docs/support/legal/*.html`) reachable at the same domain.
- No new build tooling — plain HTML/CSS, matching how the legal pages are
  already built.
- Contact email across all pages updated to `ngigi.nyongo@gmail.com`.

## Non-goals

- No JS framework, no client-side interactivity beyond a pure-CSS responsive
  nav.
- No forms, no dynamic/API-backed content — everything ships static.
- Not changing where the Flutter app or backend are hosted.

## Hosting

GitHub Pages already serves this repo's `docs/` folder on `main`. We add a
custom domain rather than switching hosts:

- `docs/CNAME` containing `shamba.samtama.lol` — tells GitHub Pages to accept
  and serve that hostname. (The DNS-side CNAME record, `shamba` →
  `ngigin.github.io`, has already been added in Cloudflare.)
- `samtama.lol` is already an authorized domain on the OAuth consent screen;
  Google's authorized-domain check is at the registrable-domain level, so
  `shamba.samtama.lol` is covered automatically — no separate authorization
  needed.
- **Manual step (developer, not Claude):** the Cloudflare record is currently
  "Proxied" (orange cloud). This commonly blocks GitHub's automatic Let's
  Encrypt certificate issuance, since GitHub needs to reach its own server
  directly to complete the HTTP-01 challenge. Set it to **DNS only** (grey
  cloud) until GitHub Pages shows the domain verified and "Enforce HTTPS"
  becomes available; it can be reconsidered afterward.
- **Manual step (developer, not Claude):** once HTTPS is live, update the
  OAuth consent screen branding page:
  - Application home page → `https://shamba.samtama.lol/`
  - Privacy policy link → `https://shamba.samtama.lol/support/legal/privacy-policy.html`
  - Terms of service link → `https://shamba.samtama.lol/support/legal/terms-of-service.html`

## File structure

```
docs/
  CNAME                      → "shamba.samtama.lol"
  index.html                 → landing page
  404.html                   → not-found page
  styles.css                 → landing page styles (shares color tokens
                                with support/legal/style.css)
  assets/
    logo.png                 → copy of assets/images/farmer_app.png
    hero.jpg                 → copy of assets/images/shamba_feature_graphic.jpg
  support/legal/
    privacy-policy.html      → edit: contact email, back-to-home link
    privacy-policy.md        → edit: contact email (kept in sync)
    terms-of-service.html    → edit: contact email, back-to-home link
    terms-of-service.md      → edit: contact email (kept in sync)
    delete-account.html      → edit: contact email, back-to-home link
    style.css                → unchanged
```

## Landing page content

**Nav** (sticky top, same on all viewport widths — pure CSS collapse on
narrow screens, no JS): logo mark + "Shamba+" wordmark on the left; links to
`#features`, Privacy Policy, Terms of Service, Delete Account on the right.

**Hero:**
- `assets/hero.jpg` (the feature graphic) displayed prominently, `alt`
  text: "Shamba+ — Farm Finance Made Simple. Secure, Grow, Sustain."
- Real semantic heading next to/below it (not relying on the image's baked-in
  text for accessibility/SEO, and directly answering the "doesn't explain
  the app's purpose" verification issue):
  - `<h1>Shamba+</h1>`
  - Subhead: "Farm Finance Made Simple"
  - Paragraph: "Shamba+ helps Kenyan farmers track crops, livestock, income,
    and expenses in one place — so you always know where your farm stands,
    and can make confident decisions about what's next."

**Features section** (`id="features"`), three cards echoing the graphic's
value props with real descriptions of what the app does:
- **Secure** — "Google Sign-In and encrypted storage keep your farm and
  financial records safe — only you can access them."
- **Grow** — "Track crops, livestock, income, and expenses in one place, and
  see clear trends as your farm grows."
- **Sustain** — "Simple, data-backed record-keeping that helps you make
  better decisions season after season."

**Footer:** logo mark, "© 2026 Shamba+", links to the three legal pages,
contact email (`ngigi.nyongo@gmail.com`).

## Legal pages edits

- Replace `mailto:support@samtama.lol` / `support@samtama.lol` with
  `ngigi.nyongo@gmail.com` in `privacy-policy.html`, `privacy-policy.md`,
  `terms-of-service.html`, `terms-of-service.md`, `delete-account.html`.
  (`terms-of-service.html` already has one contact line using
  `ngigi.nyongo@gmail.com` and others using `support@samtama.lol` — all
  become `ngigi.nyongo@gmail.com` for consistency.)
- Add a small "← Back to Shamba+" link near the top of each page, pointing
  to `/`.

## Accessibility / performance / error-state practices

- Explicit width/height (or `aspect-ratio`) on all images to avoid layout
  shift.
- Hero image loaded eagerly (above the fold); no other images need lazy
  loading at this scale.
- `docs/404.html` styled consistently with the rest of the site.
- Meaningful `alt` text throughout; semantic HTML (`<nav>`, `<main>`,
  `<footer>`, one `<h1>`).
- `<meta name="description">` and Open Graph tags (`og:title`,
  `og:description`, `og:image` using the hero graphic) for link previews.
- `prefers-color-scheme` light/dark support, matching the CSS custom
  properties already defined in `support/legal/style.css`.

## Verification plan

- Open `docs/index.html` and the edited legal pages directly in a browser
  (`file://`) to check layout/content before pushing.
- After DNS/HTTPS is live: load `https://shamba.samtama.lol/` and confirm
  nav links resolve, hero image loads, and light/dark mode both render
  correctly.
- Re-run OAuth consent screen verification after updating the branding
  fields.

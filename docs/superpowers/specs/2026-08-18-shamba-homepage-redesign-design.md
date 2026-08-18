# Shamba+ Homepage Redesign & SEO — Design

## Motivation

Google's OAuth consent screen verification has twice flagged the homepage
(`https://shamba.samtama.lol/`) for not clearly explaining the app's purpose,
even after an About section was added
([[2026-08-12-shamba-landing-page-design]],
[[2026-08-12-landing-page-about-section-design]]). Separately, the page is
thin — one hero, one About card, three feature cards — and its SEO/meta
coverage is far behind the developer's own portfolio site
(`https://portfolio.samtama.lol`), which has full Open Graph, Twitter Card,
and JSON-LD structured data. Before the next OAuth re-scrape, the goal is to
make the homepage both more substantial (clearer, more explicit about what
the app does and who it's for) and more crawlable (richer meta/structured
data so scrapers extract the right information immediately).

Two other local projects informed this redesign:
- `/home/ngigi/Documents/learning/playground/pet_store/` (Havannah Pet
  Store) — a static HTML/CSS/JS site with a noticeably more structured
  visual language: a serif+sans font pairing, inline SVG icon badges, a
  trust-signal strip, bordered section headers, and card grids.
- `https://portfolio.samtama.lol` — reveals (via its CSS module class
  names) that the developer's own site is built on **Fraunces + Work Sans +
  IBM Plex Mono**, and has full Twitter Card tags, expanded Open Graph tags,
  and JSON-LD (`WebSite` + `Person`) structured data.

## Goals

- Restructure `docs/index.html` with more content, better explaining what
  Shamba+ does and who it's for, without inventing unverifiable claims (the
  app is still in closed testing — no user counts, ratings, or download
  badges).
- Adopt pet_store's structural/visual patterns (font pairing, icon badges,
  trust strip, section headers, button styles) rebuilt for Shamba+ using the
  **Fraunces + Work Sans** pairing (matching the developer's own portfolio
  brand) rather than pet_store's Playfair Display.
- Bring homepage SEO/meta up to the standard set by the portfolio site:
  robots meta, canonical link, full Twitter Card tags, expanded Open Graph
  tags, and JSON-LD structured data.
- Add `docs/robots.txt` and `docs/sitemap.xml` so crawlers discover all
  pages immediately.
- Retain all existing copy (Hero H1/tagline/lede, About's two paragraphs,
  the three Secure/Grow/Sustain feature descriptions) verbatim.

## Non-goals

- No changes to `docs/support/legal/*` content or styling.
- No Play Store badge/CTA — app is still in closed testing.
- No screenshots section — no screenshot assets exist yet.
- No FAQ section.
- No JS framework, build step, or client-side interactivity — plain static
  HTML/CSS, inline SVG icons only, same as today.
- No fabricated social proof (user counts, star ratings, testimonials).

## Page structure

Order: Nav → Hero → Trust strip → About → How it works → Features → Who
it's for → Footer.

**Nav** (sticky, unchanged mechanics — pure CSS flex-wrap, no JS/hamburger):
logo mark + "Shamba+" wordmark on the left; links to `#about`,
`#how-it-works`, `#features`, `#who-its-for` on the right. Legal links move
out of the nav and into the footer (see Footer below) — the homepage still
satisfies "must link to privacy policy," it's just no longer competing with
content anchors for nav space.

**Hero** (content unchanged): existing `<h1>Shamba+</h1>`, `.tagline` "Farm
Finance Made Simple", `.lede` paragraph, and hero image all stay exactly as
they are today. Additions:
- A small badge above the heading: "Built for Kenyan Farmers" (pet_store's
  `.badge` pattern).
- Two CTA buttons below the lede: primary "How It Works" (→
  `#how-it-works`), outline "About Shamba+" (→ `#about`) — pet_store's
  `.hero-actions` / `.btn-primary` / `.btn-outline` pattern.

**Trust strip** (new, `role="region" aria-label="Trust signals"`, no
heading — matches pet_store's trust-strip exactly in role, styled the same
way). Four icon+text items, each a direct restatement of existing
About/Features copy so nothing new is being claimed:
1. Google Secure Sign-In
2. Crops, livestock & finances — one place
3. Encrypted, private records
4. Built for Kenyan smallholder farms

**About** (`id="about"`): unchanged — both existing paragraphs, unchanged
`.about-card` styling (icon/font updates only, no copy changes).

**How it works** (new, `id="how-it-works"`): section header `<h2>How
Shamba+ works</h2>` with a one-line subhead ("From sign-in to season-end
numbers, in four steps."), then four step cards (numbered badge + icon +
`<h3>` + short description), each visually consistent with the
`.feature-card` treatment:
1. **Sign in with Google** — One tap, no new password to create or
   remember.
2. **Set up your farm** — Add your land, crops, seasons, and livestock.
3. **Log as you go** — Record costs, inputs, harvests, and revenue as they
   happen.
4. **See the full picture** — Track trends across seasons and know exactly
   where your farm stands.

**Features** (`id="features"`): existing three cards retained verbatim
(Secure / Grow / Sustain, exact existing copy), now under a section header
`<h2>Why Shamba+</h2>`. Card headings become `<h3>` (was `<h2>`) to keep
heading hierarchy correct now that the section has its own `<h2>`. Each
card gets a matching icon badge (shield / trending-up / sprout).

**Who it's for** (new, `id="who-its-for"`): section header `<h2>Who
Shamba+ is for</h2>`, one paragraph, and four tag chips:
> Shamba+ is built for Kenyan smallholder farmers — whether you grow crops,
> keep livestock, or run a mixed operation — who are ready to trade paper
> notebooks and guesswork for a clear, always-current record of how their
> farm is really doing.

Chips: `Crop farmers` · `Livestock keepers` · `Mixed farms` · `Family-run
smallholdings`.

**Footer** (restructured, pet_store's footer pattern): logo mark + "Shamba+"
wordmark, footer nav (`Privacy Policy`, `Terms of Service`, `Delete
Account`), centered `© 2026 Shamba+` line. This is where the three legal
links now live (moved out of the top nav).

## Visual system

- **Fonts**: Google Fonts `Fraunces` (headings — `<h1>`/`<h2>`/`<h3>`,
  weights 400/600/700, matching the developer's portfolio) + `Work Sans`
  (body text, weights 400/500/600), loaded via `<link
  rel="preconnect">`/`<link>` in `<head>`, same loading pattern pet_store
  uses.
- **Color**: unchanged — existing `--bg`/`--surface`/`--text`/`--muted`/
  `--accent`/`--border`/`--danger` custom properties and light/dark
  `prefers-color-scheme` blocks stay as-is. New elements (badge, chips,
  trust strip, step-number badges) reuse `--accent` and a new
  `--accent-soft` (a low-opacity tint of `--accent`, defined per color
  scheme) for chip/badge backgrounds.
- **Icons**: inline SVG, stroke-based (`stroke="currentColor"
  stroke-width="2"`), no icon font/library — same technique pet_store uses.
  One icon per trust-strip item, one per how-it-works step, one per feature
  card, assigned as:
  - Trust strip: lock (Google Secure Sign-In) · layers (Crops, livestock &
    finances) · shield-check (Encrypted, private records) · map-pin (Built
    for Kenyan smallholder farms).
  - How it works: log-in (Sign in with Google) · map (Set up your farm) ·
    pencil (Log as you go) · bar-chart (See the full picture).
  - Features: shield (Secure) · trending-up (Grow) · sprout (Sustain).
- **Buttons**: new `.btn`, `.btn-primary`, `.btn-outline` classes (pet_store
  naming/behavior) for the hero CTAs.

## SEO / meta

In `docs/index.html` `<head>`, in addition to what's already there:
- `<meta name="robots" content="index, follow">`
- `<link rel="canonical" href="https://shamba.samtama.lol/">`
- Twitter Card: `twitter:card` (`summary_large_image`), `twitter:title`,
  `twitter:description`, `twitter:image` (hero.jpg), `twitter:image:alt`.
- Expanded Open Graph: `og:url`, `og:site_name` ("Shamba+"), `og:locale`
  ("en_KE"), `og:image:type` (`image/jpeg`), `og:image:width` (1168),
  `og:image:height` (784), `og:image:alt`.
- Two `theme-color` meta tags (light/dark, matching `--bg` token values)
  scoped with `media="(prefers-color-scheme: ...)"`.
- JSON-LD (`<script type="application/ld+json">`, array of two objects):
  a `WebSite` entry (`name`, `url`) and a `MobileApplication` entry
  (`name`, `description` — reusing the existing meta description verbatim,
  `url`, `operatingSystem: "Android"`, `applicationCategory:
  "FinanceApplication"`, `inLanguage: "en"`, `author: {"@type":
  "Organization", "name": "SaMTama"}`). No `aggregateRating` or `offers` —
  the app isn't public yet and those would be fabricated.

New files:
- `docs/robots.txt` — `User-agent: *` / `Allow: /` / `Sitemap:
  https://shamba.samtama.lol/sitemap.xml`.
- `docs/sitemap.xml` — four `<url>` entries: the homepage and the three
  legal pages.

## File structure

```
docs/
  index.html         → full content/structure rewrite (this design)
  styles.css          → new rules for badge, hero-actions/buttons, trust
                         strip, how-it-works steps, feature icons, who-its-
                         for chips, restructured footer; existing rules for
                         nav/hero/about/features kept and adjusted in place
  robots.txt           → new
  sitemap.xml           → new
  support/legal/*        → unchanged
```

## Accessibility / performance practices (carried over + extended)

- Explicit width/height on all images (unchanged hero image sizing).
- Semantic HTML: one `<h1>`, correctly nested `<h2>`/`<h3>` per section,
  `<nav aria-label>`, trust strip as `role="region"` with `aria-label`.
- Meaningful `alt` text throughout, including new icons (`aria-hidden="true"`
  on decorative SVGs, same as pet_store).
- Font loading uses `preconnect` + `display=swap` to avoid blocking render.
- `prefers-color-scheme` light/dark support extended to all new elements.

## Verification plan

- Serve locally (`python3 -m http.server --directory docs`) and visually
  check: nav shows About/How it works/Features/Who it's for in that order
  and each anchor scrolls correctly; trust strip, how-it-works steps,
  feature cards, and who-it's-for chips all render with icons in both light
  and dark mode; footer shows logo + legal nav + copyright.
- View page source and confirm all new `<head>` tags (robots, canonical,
  Twitter Card, expanded OG, JSON-LD) are present and well-formed (validate
  the JSON-LD block parses as valid JSON).
- Fetch `docs/robots.txt` and `docs/sitemap.xml` locally to confirm they're
  served and well-formed.
- Push and confirm the live site at `https://shamba.samtama.lol/` reflects
  all changes, then re-run OAuth consent screen verification.

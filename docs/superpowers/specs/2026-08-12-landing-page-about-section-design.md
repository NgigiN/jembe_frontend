# Landing Page About Section & Footer Simplification — Design

## Motivation

Google's OAuth verification still flags "your home page does not explain the
purpose of your app" even after the Shamba+ landing page went live. The
current hero has only a one-paragraph purpose statement; a dedicated,
substantive About section gives the reviewer (and real visitors) a clearer,
harder-to-miss explanation, alongside a tidier footer.

## Goals

- Add an "About Shamba+" section to `docs/index.html` with two paragraphs
  explaining the problem Shamba+ solves and what it does, placed between
  Hero and Features.
- Add "About" to the top nav, linking to the new section.
- Simplify the footer to a single small "© 2026 Shamba+" line, dropping the
  logo, nav links, and email currently there.

## Non-goals

- No changes to the Hero section's existing H1/tagline/lede/image.
- No changes to the Features section's three existing cards.
- No changes to `docs/support/legal/*` pages.

## Content

**About section** (`id="about"`, placed after Hero, before Features), styled
as a single wide card matching the existing `.feature-card` visual language
(surface background, border, rounded corners), with text content:

> ## About Shamba+
>
> Most smallholder farms in Kenya run on paper notebooks, memory, and
> guesswork — it's hard to know whether a season was actually profitable,
> which crop or herd is pulling its weight, or where money is really going
> until it's too late to change course.
>
> Shamba+ brings your farm's records into one place: land, crops, seasons
> and harvests; animals, herds, and their activity; every cost, input, and
> revenue entry. Instead of scattered notebooks, you get a clear,
> always-up-to-date picture of your farm's finances — so you can spot what's
> working, plan the next season with real numbers, and make decisions with
> confidence instead of guesswork.

**Nav**: add `<a href="#about">About</a>` between the brand mark and
"Features" link (order: About, Features, Privacy Policy, Terms, Delete
Account).

**Footer**: replace the existing `.footer-inner` content (logo, legal nav,
email) with a single centered line: `© 2026 Shamba+`. The legal links remain
reachable via the top nav, so the homepage still satisfies "must link to
privacy policy" without the footer duplicating them.

## Styling

New CSS in `docs/styles.css`:
- `.about` section wrapper (reuses `.wrap` for width, adds vertical padding
  like `.features`).
- `.about-card`: same visual treatment as `.feature-card` (`--surface`
  background, `--border` border, 16px radius) but full-width within `.wrap`,
  with inner text constrained to a readable max-width (~700px) and centered.
- `.about-card h2`: same style as `.feature-card h2` (accent color).
- Footer CSS simplifies: `.footer-inner` becomes just centered `.copyright`
  text (existing `.copyright` rule already fits); `.footer-inner .mark-img`
  and `.site-footer nav` rules become unused and are removed.

## Verification plan

- Open the updated page locally (`python3 -m http.server --directory docs`)
  and confirm: nav shows About/Features/Privacy Policy/Terms/Delete Account
  in that order, `#about` anchor scrolls to the new section, About card
  renders with both paragraphs, footer shows only "© 2026 Shamba+".
- Screenshot via headless chromium to visually confirm layout in both light
  and dark mode.
- Push and confirm the live site at `https://shamba.samtama.lol/` reflects
  the changes before the user retries OAuth verification.

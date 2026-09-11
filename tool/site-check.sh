#!/usr/bin/env bash
# Static invariants for the Shamba+ marketing site (frontend/docs).
# Usage: scripts/site-check.sh   (run from the frontend repo root)
set -u
cd "$(dirname "$0")/.."
D=docs
fail=0
pass() { echo "PASS $1"; }
failc() { echo "FAIL $1 — $2"; fail=1; }

# title
if grep -q '<title>Shamba+ — Farm finance for Kenyan smallholders</title>' $D/index.html; then pass title; else failc title "exact <title> missing"; fi

# name-consistency
if grep -rqE 'Shamba \+|Shamba Plus|ShambaPlus' $D --include=*.html --include=*.xml; then failc name-consistency "variant spelling found"; \
elif [ "$(grep -o 'Shamba+' $D/index.html | wc -l)" -lt 8 ]; then failc name-consistency "fewer than 8 'Shamba+' in index"; \
else pass name-consistency; fi

# no-samtama-caps
if grep -rq 'SaMTama' $D --include=*.html --include=*.md --include=*.xml; then failc no-samtama-caps "SaMTama still present"; else pass no-samtama-caps; fi

# privacy-in-header
if awk '/<header/,/<\/header>/' $D/index.html | grep -q 'href="/support/legal/privacy-policy.html"'; then pass privacy-in-header; else failc privacy-in-header "no privacy link inside <header>"; fi

# no-google-fonts
if grep -rqE 'fonts\.googleapis|fonts\.gstatic|preconnect' $D --include=*.html --include=*.css; then failc no-google-fonts "external font reference found"; else pass no-google-fonts; fi

# no-hero-jpg
if grep -rq 'hero.jpg' $D --include=*.html || [ -e $D/assets/hero.jpg ]; then failc no-hero-jpg "hero.jpg still referenced or present"; else pass no-hero-jpg; fi

# no-dark-mode
if grep -rq 'prefers-color-scheme' $D --include=*.css --include=*.html; then failc no-dark-mode "prefers-color-scheme found"; else pass no-dark-mode; fi

# section-order
ids=$(grep -oE 'id="(top|what|how|google|maker|believe|today)"' $D/index.html | sed 's/id="//;s/"//' | tr '\n' ' ')
if [ "$ids" = "top what how google maker believe today " ]; then pass section-order; else failc section-order "got: $ids"; fi

# mailto-cta
n=$(grep -o 'mailto:ngigi.nyongo@gmail.com?subject=Shamba%2B%20early%20access' $D/index.html | wc -l)
if [ "$n" -ge 2 ]; then pass mailto-cta; else failc mailto-cta "expected >=2 early-access mailto links, got $n"; fi

# lede
if grep -q 'Shamba+ is an Android app that keeps your land, crops, seasons, harvests, livestock, costs and sales in one place, and shows what each season made or lost.' $D/index.html; then pass lede; else failc lede "purpose sentence missing"; fi

# google-section
if grep -q '<h2>How Shamba+ uses your Google account</h2>' $D/index.html && grep -q 'Limited Use' $D/index.html; then pass google-section; else failc google-section "h2 or Limited Use sentence missing"; fi

# fonts-present
if [ -s $D/assets/fonts/Fraunces-var.woff2 ] && [ -s $D/assets/fonts/WorkSans-var.woff2 ] && [ -s $D/assets/fonts/OFL-Fraunces.txt ] && [ -s $D/assets/fonts/OFL-WorkSans.txt ]; then pass fonts-present; else failc fonts-present "font files or licences missing"; fi

# screenshot-present
if [ -s $D/assets/screens/analytics.png ] && grep -q 'assets/screens/analytics.png' $D/index.html; then pass screenshot-present; else failc screenshot-present "analytics.png missing or unreferenced"; fi

# og-present
if [ -s $D/assets/og.png ] && grep -q 'content="https://shamba.samtama.lol/assets/og.png"' $D/index.html; then pass og-present; else failc og-present "og.png missing or unreferenced"; fi

# css-braces
ok=1
for f in $D/styles.css $D/support/legal/style.css; do
  o=$(grep -o '{' $f | wc -l); c=$(grep -o '}' $f | wc -l)
  [ "$o" -eq "$c" ] || { ok=0; failc css-braces "$f has $o '{' vs $c '}'"; }
done
[ $ok -eq 1 ] && pass css-braces

# privacy-content
P=$D/support/legal/privacy-policy.html
missing=""
for s in 'Anthropic' 'Germany' '30 days' '90 days' 'odpc.go.ke' 'Samuel Ngigi' 'Limited Use' 'samTama' 'id="third-parties"'; do
  grep -q "$s" $P || missing="$missing [$s]"
done
if [ -z "$missing" ]; then pass privacy-content; else failc privacy-content "missing:$missing"; fi

# delete-page-name
if grep -q 'samTama' $D/support/legal/delete-account.html && grep -q 'Shamba+' $D/support/legal/delete-account.html; then pass delete-page-name; else failc delete-page-name "app/developer name missing"; fi

# no-md-legal
if ls $D/support/legal/*.md >/dev/null 2>&1; then failc no-md-legal "markdown duplicates still present"; else pass no-md-legal; fi

# jsonld
if grep -q '"@type": "Organization"' $D/index.html && grep -q '"name": "samTama"' $D/index.html && grep -q '"name": "Samuel Ngigi"' $D/index.html && grep -q '"@type": "SoftwareApplication"' $D/index.html; then pass jsonld; else failc jsonld "Organization/Person/SoftwareApplication JSON-LD incomplete"; fi

exit $fail

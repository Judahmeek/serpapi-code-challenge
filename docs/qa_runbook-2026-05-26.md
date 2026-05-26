# Google Carousel Parser — QA Runbook

**Audience:** QA engineer verifying the `GoogleCarousel::Parser` feature  
**Branch:** `feat/google-carousel-parser`  
**Date:** 2026-05-26

---

## Overview

This runbook guides end-to-end verification of the Google Carousel Parser. The parser reads a saved Google Search HTML file and extracts carousel items (name, year, link, thumbnail) without making any HTTP requests.

**Pass criteria for this feature:**
- All 30 automated tests pass with 0 failures
- Line coverage is 100%
- RuboCop reports 0 offenses on `lib/`
- Integration output for the Van Gogh HTML matches the gold-standard JSON file exactly

---

## Environment Setup

### 1. Check out the feature branch

```bash
git checkout feat/google-carousel-parser
```

### 2. Install dependencies

```bash
bundle install
```

Verify Bundler resolves without errors. All gems are pre-locked in `Gemfile.lock` — no internet access is needed if the gem cache is warm.

### 3. Verify Ruby version

```bash
ruby --version
# Expected: ruby 4.0.2
```

If the version does not match, use a version manager (rbenv, asdf, rvm) to install Ruby 4.0.2.

---

## Test Scenarios

### Scenario 1 — Full test suite

**Purpose:** Single command to verify all behaviour.

**Command:**
```bash
bundle exec rspec --format documentation
```

**Expected output (summary line):**
```
42 examples, 0 failures
```

**Expected coverage line (printed after the summary):**
```
Line Coverage: 100.0% (93 / 93)
```

**Pass:** Both lines appear exactly as shown.  
**Fail:** Any example marked `F` (failure) or `*` (pending), or coverage below 100%.

---

### Scenario 2 — Integration test against real Google HTML

**Purpose:** Verify the parser produces the correct 47 items from the actual Van Gogh paintings search result page saved in this repository.

**Command:**
```bash
bundle exec rspec spec/google_carousel/parser_spec.rb \
  -e "Van Gogh paintings integration" \
  --format documentation
```

**Expected output:**
```
GoogleCarousel::Parser
  #parse — Van Gogh paintings integration
    returns 47 items
    matches all items in the expected array exactly
```

**What "matches all items" means:** The parser output is compared item-by-item against `files/expected-array.json`. Every painting's `name`, `extensions`, `link`, and `image` must be identical. Items with no year in the source HTML produce `extensions: []`.

**Manual spot-check (optional):**
```bash
ruby -e "
  require_relative 'lib/google_carousel'
  items = GoogleCarousel::Parser.new.parse(
    File.read('files/van-gogh-paintings.html'),
    base_url: 'https://www.google.com'
  )
  puts \"Item count: #{items.count}\"
  puts items.first.inspect
"
```

Expected first item:
```
#<data GoogleCarousel::CarouselItem
  name=\"The Starry Night\",
  extensions=[\"1889\"],
  link=\"https://www.google.com/search?q=The+Starry+Night+painting\",
  image=\"data:image/jpeg;base64,...\"
>
```

---

### Scenario 3 — Layout A (books fixture)

**Purpose:** Verify the parser handles the traditional `img + div` carousel item structure.

**Command:**
```bash
bundle exec rspec spec/google_carousel/parser_spec.rb \
  -e "books fixture" \
  --format documentation
```

**Expected output:**
```
  #parse — books fixture (Layout A)
    returns 3 items
    extracts correct names
    extracts correct extensions
    extracts correct links
    extracts correct images
```

**What is tested:**
- 3 items extracted from a minimal synthetic HTML file
- Names: `Book One`, `Book Two`, `Book Three`
- Extensions: `["2010"]`, `["2011"]`, `["2012"]`
- Links: `/search?q=book1`, `/search?q=book2`, `/search?q=book3`
- Images: `https://example.com/b1.jpg`, `https://example.com/b2.jpg`, `https://example.com/b3.jpg`

---

### Scenario 4 — Layout B (movies fixture, `wp-grid-tile`)

**Purpose:** Verify the parser handles Google's `<wp-grid-tile>` custom element carousel structure.

**Command:**
```bash
bundle exec rspec spec/google_carousel/parser_spec.rb \
  -e "movies fixture" \
  --format documentation
```

**Expected output:**
```
  #parse — movies fixture (Layout B)
    returns 3 items
    extracts correct names
    extracts correct extensions
    extracts correct links
    extracts correct images
```

**What is tested:**
- 3 items extracted from a synthetic HTML file using `<wp-grid-tile>` markup
- Names: `Movie One`, `Movie Two`, `Movie Three`
- Extensions: `["2001"]`, `["2002"]`, `["2003"]`
- Links: `/search?q=movie1`, `/search?q=movie2`, `/search?q=movie3`
- Images: `https://example.com/m1.jpg`, `https://example.com/m2.jpg`, `https://example.com/m3.jpg`

---

### Scenario 5 — Error handling

**Purpose:** Verify the parser raises `ParseError` with the correct message for each failure mode.

**Command:**
```bash
bundle exec rspec spec/google_carousel/parser_spec.rb \
  -e "error cases" \
  --format documentation
```

**Expected output:**
```
  #parse — error cases
    raises ParseError when the search section is missing
    raises ParseError when the carousel container is missing
    raises ParseError when no carousel items are found
```

**The three error conditions:**

| Condition | Input | Expected error message |
|-----------|-------|------------------------|
| No `#search` div in HTML | `<div id="other"></div>` | `Carousel section not found` |
| `#search` exists but no `data-attrid` div inside | `<div id="search"><div>no attrid</div></div>` | `Carousel container not found within section` |
| Carousel div exists but no `div > a` children | `<div data-attrid="kc:/test"><p>no links</p></div>` | `No carousel items found (selector: 'div > a')` |

**Manual verification (optional):**
```bash
ruby -e "
  require_relative 'lib/google_carousel'
  begin
    GoogleCarousel::Parser.new.parse('<html><body></body></html>')
  rescue GoogleCarousel::ParseError => e
    puts e.class    # GoogleCarousel::ParseError
    puts e.message  # Carousel section not found
  end
"
```

---

### Scenario 6 — Configurability

**Purpose:** Verify that `DEFAULT_CONFIG.with(...)` produces a working custom parser without modifying the default.

**Command:**
```bash
bundle exec rspec spec/google_carousel/parser_spec.rb \
  -e "configurability" \
  --format documentation
```

**Expected output:**
```
  #parse — configurability
    uses the custom section_finder from a derived config
```

**What is tested:** A parser configured with a custom `section_finder` that targets `#custom-section` instead of `#search` extracts an item named `Custom Item` from HTML that has no `#search` div.

---

### Scenario 7 — Image resolution unit tests

**Purpose:** Verify all three image resolution paths work correctly.

**Command:**
```bash
bundle exec rspec spec/google_carousel/image_resolver_spec.rb \
  --format documentation
```

**Expected output:**
```
GoogleCarousel::ImageResolver
  #resolve
    inline base64 from script block
      returns the base64 string when img id matches
      falls through to data-src when img id is absent from image map
    data-src attribute
      returns the data-src URL
    src attribute
      returns src when it is a real non-GIF URL
      returns nil when src is a placeholder GIF
      returns nil when neither inline base64, data-src, nor real src are present
    multiple script blocks
      builds the correct id-to-image mapping from all scripts
```

**Key behaviours verified:**
- Inline base64 takes priority over `data-src` and `src`
- Placeholder GIF `src` values (`data:image/gif;base64,...`) return `nil`
- Multiple `<script>` blocks are all scanned (Google often packs 20+ images into a single script block)

---

## Linting Check

**Purpose:** Confirm no style violations were introduced.

**Command:**
```bash
bundle exec rubocop lib/
```

**Expected output:**
```
N files inspected, no offenses detected
```

**Pass:** `no offenses detected`  
**Fail:** Any line showing `C:`, `W:`, or `E:` offense codes.

---

## Coverage Report

After running `bundle exec rspec`, open the HTML coverage report:

```bash
# On Linux
xdg-open coverage/index.html

# On macOS
open coverage/index.html
```

**Expected:** All files show 100% line coverage. If any file shows less, note the uncovered lines and file a defect.

---

## Regression Check Against Gold Standard

**Purpose:** Direct diff of parser output vs. the expected JSON provided with the challenge.

```bash
ruby -e "
  require 'json'
  require_relative 'lib/google_carousel'

  expected = JSON.parse(File.read('files/expected-array.json'))['artworks']
  items    = GoogleCarousel::Parser.new.parse(
               File.read('files/van-gogh-paintings.html'),
               base_url: 'https://www.google.com'
             )

  mismatches = 0
  items.each_with_index do |item, i|
    exp = { extensions: [] }.merge(expected[i].transform_keys(&:to_sym))
    act = item.to_h
    next if exp == act
    mismatches += 1
    puts \"Item #{i + 1} mismatch:\"
    puts \"  Expected: #{exp.inspect}\"
    puts \"  Got:      #{act.inspect}\"
  end

  if mismatches.zero?
    puts 'All #{items.count} items match. PASS'
  else
    puts \"#{mismatches} mismatches found. FAIL\"
  end
"
```

**Expected output:**
```
All 47 items match. PASS
```

---

## Pass / Fail Summary

| Check | Command | Pass condition |
|-------|---------|----------------|
| Full test suite | `bundle exec rspec` | 42 examples, 0 failures |
| Coverage | (automatic after rspec) | 100.0% (93 / 93) |
| Integration — Van Gogh | `rspec -e "Van Gogh"` | 2 examples, 0 failures |
| Layout A — books | `rspec -e "books fixture"` | 5 examples, 0 failures |
| Layout B — movies | `rspec -e "movies fixture"` | 5 examples, 0 failures |
| Error handling | `rspec -e "error cases"` | 3 examples, 0 failures |
| Configurability | `rspec -e "configurability"` | 1 example, 0 failures |
| Linting | `bundle exec rubocop lib/` | no offenses detected |
| Gold-standard diff | manual ruby script | "All 47 items match. PASS" |

---

## Common Failure Modes

**`LoadError: cannot load such file — google_carousel`**  
→ Run from the project root directory. Check that `bundle install` completed successfully.

**`ruby: No such file or directory` on `files/van-gogh-paintings.html`**  
→ Run from the project root. The `files/` directory must be present.

**Wrong Ruby version error**  
→ Switch to Ruby 4.0.2 with your version manager: `rbenv local 4.0.2` or `asdf local ruby 4.0.2`.

**`Bundler::GemNotFound`**  
→ Re-run `bundle install`. If behind a firewall, ensure rubygems.org is accessible or a local gem mirror is configured.

**Item count mismatch (e.g. 43 instead of 47)**  
→ The image resolver may have regressed. Run `bundle exec rspec spec/google_carousel/image_resolver_spec.rb` and check for failures.

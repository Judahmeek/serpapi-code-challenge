# Google Carousel Parser — Developer Guide

## Overview

`GoogleCarousel::Parser` extracts structured data from Google Knowledge Graph carousel sections in saved HTML search result pages. It handles two carousel item layouts used by Google and returns an array of `CarouselItem` value objects.

Each item contains:

| Field | Type | Description |
|-------|------|-------------|
| `name` | `String \| nil` | Item title |
| `extensions` | `Array<String>` | Metadata labels (year, genre, etc.) |
| `link` | `String \| nil` | Raw or resolved Google search URL |
| `image` | `String \| nil` | Base64 data URI or HTTPS thumbnail URL |

---

## Requirements

- Ruby 4.0.2 (pinned in `Gemfile`)
- Bundler 4.0+

---

## Installation

```bash
git clone <repo-url>
cd <repo-dir>
bundle install
```

No system dependencies beyond Ruby and Bundler. All gems are locked in `Gemfile.lock`.

---

## Usage

### Basic parse

```ruby
require_relative 'lib/google_carousel'

html  = File.read('files/van-gogh-paintings.html')
items = GoogleCarousel::Parser.new.parse(html, base_url: 'https://www.google.com')

items.each do |item|
  p item.name        # => "The Starry Night"
  p item.extensions  # => ["1889"]
  p item.link        # => "https://www.google.com/search?q=The+Starry+Night+painting"
  p item.image       # => "data:image/jpeg;base64,..."
end
```

`base_url` is optional. When provided, relative `href` values are resolved to absolute URLs via `URI.join`. Omit it when the HTML already contains absolute links or when you do not need resolved URLs.

### Serializing to hash

`CarouselItem` is a `Data.define` value object. `#to_h` always emits all four keys:

```ruby
items.first.to_h
# => { name: "The Starry Night", extensions: ["1889"], link: "https://...", image: "data:..." }
```

### Serializing to JSON

`JsonSerializer` wraps an array of `CarouselItem` objects and produces a JSON string
matching the `expected-array.json` format:

```ruby
items = GoogleCarousel::Parser.new.parse(html, base_url: 'https://www.google.com')
json  = GoogleCarousel::JsonSerializer.new(items).to_json
# => '{"artworks":[{"name":"The Starry Night","extensions":["1889"],...}]}'
```

The root key defaults to `"artworks"` and is overridable:

```ruby
GoogleCarousel::JsonSerializer.new(items, root_key: 'paintings').to_json
```

`extensions` is omitted per item when the array is empty. `name`, `link`, and `image`
are omitted when `nil`.

---

## Custom Configuration

All extraction logic is encapsulated in `CarouselConfig`. The library ships with `DEFAULT_CONFIG` which targets Google's current carousel markup. Override individual callables via `#with` — no subclassing needed:

```ruby
custom_config = GoogleCarousel::DEFAULT_CONFIG.with(
  section_finder: ->(doc) { doc.at_css('#my-custom-section') }
)

parser = GoogleCarousel::Parser.new(config: custom_config)
items  = parser.parse(html)
```

The six configurable callables:

| Field | Signature | Default behaviour |
|-------|-----------|-------------------|
| `section_finder` | `(doc) → node\|nil` | `doc.at_css('#search')` |
| `carousel_finder` | `(section) → node\|nil` | First `div` whose `data-attrid` starts with `kc:/`. Known values: `kc:/visual_art/visual_artist:works` (artworks), `kc:/people/person:movies` (filmography), `kc:/music/artist:albums` (discography) |
| `item_selector` | CSS string | `'div > a'` |
| `name_extractor` | `(item_node) → String\|nil` | Layout A name div, falling back to Layout B |
| `extension_extractor` | `(item_node) → Array<String>` | Layout A extension divs, falling back to Layout B |
| `link_extractor` | `(item_node) → String\|nil` | `node['href']` |

---

## Error Handling

`GoogleCarousel::ParseError` is raised when the HTML structure does not match configuration:

```ruby
begin
  items = parser.parse(html)
rescue GoogleCarousel::ParseError => e
  puts e.message
  # Possible messages:
  #   "Carousel section not found"
  #   "Carousel container not found within section"
  #   "No carousel items found (selector: 'div > a')"
end
```

---

## Running Tests

```bash
# Full suite
bundle exec rspec

# Human-readable output
bundle exec rspec --format documentation

# Single spec file
bundle exec rspec spec/google_carousel/parser_spec.rb

# Single example by name
bundle exec rspec spec/google_carousel/parser_spec.rb -e "returns 47 items"
```

Expected result: **36 examples, 0 failures**, 100% line coverage.

A SimpleCov HTML report is written to `coverage/index.html` after every run.

---

## Linting

```bash
bundle exec rubocop lib/
```

`spec/` is excluded from RuboCop checks (configured in `.rubocop.yml`).

---

## Architecture

```
lib/
  google_carousel.rb             # Zeitwerk loader + DEFAULT_CONFIG constant
  google_carousel/
    carousel_config.rb           # Data.define value object — six config callables
    carousel_item.rb             # Data.define value object — extracted item fields
    parser.rb                    # Orchestrator: section → carousel → items
    item_extractor.rb            # Extracts one CarouselItem from a single <a> node
    image_resolver.rb            # Resolves best image: script map > data-src > src
    json_serializer.rb           # Serializes CarouselItem array → JSON string with configurable root key

spec/
  google_carousel/
    parser_spec.rb               # Integration, layout, error, and configurability tests
    item_extractor_spec.rb       # Unit tests for ItemExtractor
    image_resolver_spec.rb       # Unit tests for ImageResolver
    json_serializer_spec.rb      # Unit + integration tests for JsonSerializer
    fixtures/
      books_carousel.html        # Minimal Layout A synthetic fixture (3 items)
      movies_carousel.html       # Minimal Layout B synthetic fixture (3 items)

files/
  van-gogh-paintings.html        # Real Google HTML page (challenge input)
  expected-array.json            # Gold-standard expected output (47 paintings)
```

### How the parser locates a carousel

1. `section_finder` finds `<div id="search">` in the document.
2. `carousel_finder` finds the first descendant `<div>` whose `data-attrid` attribute starts with `kc:/` — this is the Google Knowledge Carousel container.
3. `item_selector` (`div > a`) selects direct `<a>` children of the immediate child `<div>`.

### How images are resolved

`ImageResolver` checks three sources in priority order:

1. **Inline script map** — Google embeds many thumbnails as base64 strings inside `<script>` blocks using the pattern `var s='data:image/...'; var ii=['img-id']`. The resolver scans all scripts, builds an `id → base64` map, and looks up each `<img>` by its `id` attribute.
2. **`data-src` attribute** — used for lazily-loaded images.
3. **`src` attribute** — used directly unless it is a placeholder GIF (`data:image/gif;base64,...`), which is returned as `nil`.

### Google carousel item layouts

**Layout A** — traditional inline layout:
```html
<a href="/search?q=...">
  <img id="kximg0" src="placeholder.gif" />
  <div>
    <div>Item Name</div>
    <div>2023</div>
  </div>
</a>
```

**Layout B** — `<wp-grid-tile>` custom element:
```html
<a href="/search?q=...">
  <wp-grid-tile>
    <div><img src="https://..." /></div>
    <div>
      <div>Item Name</div>
      <div>2023</div>
    </div>
  </wp-grid-tile>
</a>
```

Both layouts are handled by `||` fallback chains in `name_extractor` and `extension_extractor` — no branching in the parser itself.

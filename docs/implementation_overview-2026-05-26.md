# Implementation Overview

This solution implements a Google Knowledge Graph carousel parser in Ruby, satisfying all requirements from the challenge: extracts `name`, `extensions` (year), `link`, and `image` (thumbnail) fields from a saved Google Search HTML page, with no HTTP requests needed.

## Architecture

The library lives in `lib/google_carousel/` and consists of six focused classes:

- **`Parser`** — top-level orchestrator: locates the carousel section in the DOM and maps each `<a>` node through `ItemExtractor`.
- **`CarouselConfig`** — a `Data.define` value object holding six configurable callables (`section_finder`, `carousel_finder`, `item_selector`, `name_extractor`, `extension_extractor`, `link_extractor`). Callers can derive a custom config via `DEFAULT_CONFIG.with(...)` without subclassing.
- **`ItemExtractor`** — applies config callables to a single DOM node and resolves relative `href` values to absolute URLs via `URI.join`.
- **`ImageResolver`** — resolves the best available thumbnail via a three-level priority chain: inline base64 from `<script>` blocks (Google's primary method) → `data-src` → real `src` (placeholder GIFs return `nil`).
- **`CarouselItem`** — a `Data.define` value object carrying the four output fields.
- **`JsonSerializer`** — serializes a `CarouselItem` array to JSON with a configurable root key (default `"artworks"`), omitting `nil` fields and empty `extensions` arrays.

## Handling Multiple Google Layouts

Google uses two carousel item structures. Both are handled by `||` fallback chains in the config lambdas — no branching in the parser itself:

- **Layout A** — traditional `img + div` inline structure
- **Layout B** — `<wp-grid-tile>` custom element structure

## Cross-page Validation

In addition to the main Van Gogh paintings page (`files/van-gogh-paintings.html`), the test suite validates against two synthetic fixture pages (`spec/google_carousel/fixtures/books_carousel.html` — Layout A, `movies_carousel.html` — Layout B), covering both layout variants.

## Test Coverage

42 RSpec examples, 0 failures, 100% line coverage (SimpleCov).

## Detailed Documentation

- [Developer Guide](google_carousel_parser_guide-2026-05-26.md) — architecture, usage examples, config API, error handling, running tests
- [QA Runbook](qa_runbook-2026-05-26.md) — step-by-step verification scenarios, pass/fail criteria, gold-standard diff script

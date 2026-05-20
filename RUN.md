# Run Guide

This file contains setup, run, lint, and test commands for this script.

## Prerequisites

- Ruby
- Bundler

## Setup

Install dependencies:

```bash
bundle install
```

## Run Extractor

Run extractor on the provided fixture:

```bash
bin/extract files/van-gogh-paintings.html
```

Save output:

```bash
bin/extract files/van-gogh-paintings.html > /tmp/artworks.json
```

Programmatic use:

```ruby
require_relative "lib/extractor"

result = Extractor.call("files/van-gogh-paintings.html")
puts result.first
```

## Run Tests

Run all specs:

```bash
bundle exec rspec
```

Run one spec file:

```bash
bundle exec rspec spec/extractor_spec.rb
```

## Lint

Run syntax lint checks:

```bash
bundle exec bin/lint
```

`bin/lint` runs `ruby -wc` across `lib/`, `spec/`, and `bin/`.

## Local Quality Checks

1. `bundle exec bin/lint`
2. `bundle exec rspec`

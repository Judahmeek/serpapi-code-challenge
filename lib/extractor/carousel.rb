require_relative "item"

module Extractor
  # Locates the knowledge-graph carousel on a desktop Google SERP. Google
  # rotates CSS class names regularly, so we identify the carousel by its
  # structural signature: a container holding a run of sibling tiles, where
  # every tile has exactly one anchor to /search?... with a `stick=` param
  # (the knowledge-graph entity stick).
  class Carousel
    # Heuristic floor to filter tiny, usually-noisy stick-link groups.
    MIN_TILES = 3

    # Class-level convenience API keeps caller usage functional:
    #   Carousel.tiles(document)
    # while still allowing private helpers and local state internally.
    def self.tiles(document)
      new(document).tiles
    end

    # Stores the document as instance state so private methods can access
    # it without threading it through every method call.
    def initialize(document)
      @document = document
    end

    def tiles
      groups = candidate_groups
      return [] if groups.empty?

      # Multiple stick-link groups can exist on one page. We prefer the group
      # that most strongly looks like media tiles, then fall back to DOM order
      # for deterministic behavior on ties.
      # deterministic tie-breaking removes "heisenbugs" where output can vary by Ruby/hash iteration behavior.
      scored = groups.map { |g| [group_score(g), g] }
      best_score = scored.map(&:first).max
      best_groups = scored.select { |score, _| score == best_score }.map(&:last)
      best_groups.min_by { |g| document_position(g.first) } || []
    end

    private

    # Build candidate groups by:
    #   1. Finding every `/search?…&stick=…` anchor.
    #   2. Walking each anchor up to its *tile root* — the highest ancestor
    #      that still contains exactly one stick anchor.
    #   3. Grouping tile roots by their common parent. A group with
    #      MIN_TILES+ siblings is a carousel candidate.
    def candidate_groups
      # Structural fingerprint that avoids volatile CSS class names.
      anchors = @document.css('a[href*="stick="]').select do |a|
        href = a["href"].to_s
        # Relative and absolute google-search links are both accepted.
        href.start_with?("/search") || href.include?("google.com/search")
      end

      # Convert each anchor to the smallest "tile root" node that represents
      # one tile (not a nested sub-node, not the whole carousel container).
      tile_roots = anchors.map { |a| tile_root_for(a) }.compact.uniq

      # Sibling tile roots under the same parent form one carousel candidate.
      grouped = tile_roots.group_by(&:parent)
      grouped.delete(nil)

      # Drop weak candidates early.
      grouped.values.select { |g| g.size >= MIN_TILES }
    end

    # Score shape:
    #   1) tiles with an image element
    #   2) tiles with a likely name signal
    #   3) group size
    #
    # This keeps us anchored on structural evidence instead of class names.
    def group_score(group)
      # Prefer groups that look like media cards.
      with_image = group.count { |tile| tile.at_css("img") }
      # Name-like signals provide a second quality axis.
      with_name = group.count { |tile| tile.at_css('img[alt], a[aria-label], a[title]') }
      [with_image, with_name, group.size]
    end

    def document_position(node)
      return Float::INFINITY unless node
      # DOM-order fallback is stable and explainable.
      @document.css("*").index(node) || Float::INFINITY
    end

    # Walk up from `anchor` while the current node's parent still contains
    # only one stick anchor. The last such node is the tile root — adding
    # one more level would absorb sibling tiles.
    def tile_root_for(anchor)
      node = anchor
      loop do
        parent = node.parent
        return node unless parent

        # As soon as parent contains multiple stick anchors, walking higher
        # would merge sibling tiles. Current node is the tile root boundary.
        stick_count = parent.css('a[href*="stick="]').size
        return node if stick_count != 1
        node = parent
      end
    end
  end
end

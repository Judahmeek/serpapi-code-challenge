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
      target_section = @document.at_css('#search') || @document
      target_section = target_section.css('div').find { |d| d['data-attrid'] } || target_section
      name_element, name_elements = {
        'img[alt]': target_section.css('img[alt]'),
        'a[aria-label]': target_section.css('a[aria-label]'),
        'div[aria-label]': target_section.css('div[aria-label]'),
        'a[title]': target_section.css('a[title]'),
      }.max_by { |key, value| value.size }

      # Convert each anchor to the smallest "tile root" node that represents
      # one tile (not a nested sub-node, not the whole carousel container).
      tile_roots = name_elements.map { |a| tile_root_for(a, name_element) }.compact.uniq

      # Sibling tile roots under the same parent form one carousel candidate.
      grouped = tile_roots.group_by { |root| root.parent.to_s.hash + root.parent.element_children.size }
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
      score = 0
      # Prefer groups that look like media cards.
      score += 1 if group.count { |tile| tile.at_css("img") } == group.size
      # properly formatted anchor links provide a second quality axis.
      score += 1 if group.count { |tile| tile.at_css('a[href*="stick="]') } == group.size
      score * group.size
    end

    def document_position(node)
      return Float::INFINITY unless node
      # DOM-order fallback is stable and explainable.
      @document.css("*").index(node) || Float::INFINITY
    end

    # Walk up from the current root while the current node's parent still contains
    # only one specific element. The last such node is the tile root — adding
    # one more level would absorb sibling tiles.
    def tile_root_for(current_root, name_element)
      node = current_root
      loop do
        parent = node.parent
        return node unless parent

        # As soon as parent contains multiple stick anchors, walking higher
        # would merge sibling tiles. Current node is the tile root boundary.
        stick_count = parent.css(name_element).size
        return node if stick_count != 1
        node = parent
      end
    end
  end
end

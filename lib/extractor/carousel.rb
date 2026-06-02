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
      @root_selector = nil
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
      best_root_candidate = [
        { elements: target_section.css('img[alt]'), priority: 0, selector: 'img[alt]' },
        { elements: target_section.css('[title]'), priority: 1, selector: '[title]' },
        { elements: target_section.css('[aria-label]'), priority: 2, selector: '[aria-label]' },
        { elements: target_section.css('a[href*="stick="]'), priority: 3, selector: 'a[href*="stick="]' },
      ].max_by { |entry| [ entry[:elements].size, -entry[:priority] ] }
      @root_selector = best_root_candidate[:selector]

      # Convert each anchor to the smallest "tile root" node that represents
      # one tile (not a nested sub-node, not the whole carousel container).
      tile_roots = best_root_candidate[:elements].map { |a| tile_root_for(a) }.compact.uniq

      # Sibling tile roots under the same parent form one carousel candidate.
      grouped = tile_roots.group_by { |root| root.parent.to_s.hash + root.parent.element_children.size }
      grouped.delete(nil)

      # Drop weak candidates early.
      grouped.values.select { |g| g.size >= MIN_TILES }
    end

    # Score shape:
    #   1) tiles with an image element
    #   2) tiles with a properly formatted anchor links
    #   3) tiles with a likely name signal
    #   4) group size
    #
    # This keeps us anchored on structural evidence instead of class names.
    def group_score(group)
      default_weight = ENV.fetch('DEFAULT_TILE_WEIGHT', 1.1).to_f 
      acceptable_number_of_misformed_tiles = ENV.fetch('ACCEPTABLE_NUMBER_OF_MISFORMED_TILES', 0).to_i
      tile_img_weight    = ENV.fetch('TILE_IMG_WEIGHT', default_weight).to_f
      tile_anchor_weight    = ENV.fetch('TILE_ANCHOR_WEIGHT', default_weight).to_f
      tile_name_weight    = ENV.fetch('TILE_NAME_WEIGHT', default_weight).to_f
      # Prefer groups that look like media cards.
      almost_all_tiles_have_images = @root_selector == 'img[alt]' || group.count { |tile| tile.at_css("img") } >= group.size - acceptable_number_of_misformed_tiles
      img_score = almost_all_tiles_have_images ? tile_img_weight : 1
      # properly formatted anchor links provide a second quality axis.
      almost_all_tiles_have_anchors = @root_selector == 'a[href*="stick="]' || group.count { |tile| tile.at_css('a[href*="stick="]') } >= group.size - acceptable_number_of_misformed_tiles
      anchor_score = almost_all_tiles_have_anchors ? tile_anchor_weight : 1
      # Name-like signals provide a third quality axis.
      almost_all_tiles_have_names = ['[title]', '[aria-label]', 'img[alt]'].include?(@root_selector) || group.count { |tile| tile.at_css('[title], [aria-label], img[alt]') } >= group.size - acceptable_number_of_misformed_tiles
      name_score = almost_all_tiles_have_names ? tile_name_weight : 1
      group.size * img_score * anchor_score * name_score
    end

    def document_position(node)
      return Float::INFINITY unless node
      # DOM-order fallback is stable and explainable.
      @document.css("*").index(node) || Float::INFINITY
    end

    # Walk up from the current root while the current node's parent still contains
    # only one specific element. The last such node is the tile root — adding
    # one more level would absorb sibling tiles.
    def tile_root_for(current_root)
      node = current_root
      loop do
        parent = node.parent
        return node unless parent

        # As soon as parent contains multiple stick anchors, walking higher
        # would merge sibling tiles. Current node is the tile root boundary.
        stick_count = parent.css(@root_selector).size
        return node if stick_count != 1
        node = parent
      end
    end
  end
end

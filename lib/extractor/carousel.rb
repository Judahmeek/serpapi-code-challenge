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
      # scrapeMemo psuedocode: create empty scrapeMemo hash, which will serve as an index for future parsing of the same search result structure (data-attrid, tile grid container class, tile root class, tile count, name_attribute, image_script_variable_names)
      target_section = @document.at_css('#search') || @document
      # scrapeMemo psuedocode: if '#search' can't be found, add that to scrapeMemo hash
      target_section = target_section.css('div').find { |d| d['data-attrid'] } || target_section
      # scrapeMemo psuedocode: if div['data-attrid'] can't be found, add that to scrapeMemo hash
      # scrapeMemo psuedocode: check database for any records containing the same ['data-attrid'] value
      # scrapeMemo psuedocode: if one or more record(s) exist, scan for the tile grid container class, prioritizing the record most recently created
      # scrapeMemo psuedocode: if the tile grid container exists & has the expected number of children with the expected tile root class, set them as the tile roots & skip the rest of this function

      groups = candidate_groups(target_section)
      return [] if groups.empty?

      # Multiple stick-link groups can exist on one page. We prefer the group
      # that most strongly looks like media tiles, then fall back to DOM order
      # for deterministic behavior on ties.
      # deterministic tie-breaking removes "heisenbugs" where output can vary by Ruby/hash iteration behavior.
      scored = groups.map { |g| [group_score(g), g] }
      best_score = scored.map(&:first).max
      best_groups = scored.select { |score, _| score == best_score }.map(&:last)
      best_groups.min_by { |g| document_position(g.first) } || []
      # scrapeMemo psuedocode: just like with the div['data-attrid'] value before, we can now check the tile grid container class, tile root class, tile count, as well as the div['data-attrid'] value against recorded indexes to check for search result structure drift
    end

    private

    # before = Time.now
    # for i in 1..1000
    #   candidate_groups(target_section)
    # end
    # after = Time.now
    # puts "new version benchmarked at #{after - before}"

    # Build candidate groups by finding the three biggest sibling groups within the target section
    # I tested this versus the previous implementation with the quick & dirty benchmark commented out above
    # against the van-gogh-paintings.html results and found this to be about x10 faster.
    def candidate_groups(target_section)
      target_section.css('div', 'section', 'main').max_by(3) { |element| element.element_children.count }.map { |e| e.element_children }
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
      almost_all_tiles_have_images = group.count { |tile| tile.at_css("img") } >= group.size - acceptable_number_of_misformed_tiles
      img_score = almost_all_tiles_have_images ? tile_img_weight : 1
      # properly formatted anchor links provide a second quality axis.
      almost_all_tiles_have_anchors = group.count { |tile| tile.at_css('a[href*="stick="]') } >= group.size - acceptable_number_of_misformed_tiles
      anchor_score = almost_all_tiles_have_anchors ? tile_anchor_weight : 1
      # Name-like signals provide a third quality axis.
      # I didn't think that searching for each name candidate individually to enforce uniformity
      # was worth the performance cost, but it is a tradeoff worth discussing in a code review
      almost_all_tiles_have_names = group.count { |tile| tile.at_css('[title], [aria-label], img[alt]') } >= group.size - acceptable_number_of_misformed_tiles
      name_score = almost_all_tiles_have_names ? tile_name_weight : 1
      group.size * img_score * anchor_score * name_score
    end

    def document_position(node)
      return Float::INFINITY unless node
      # DOM-order fallback is stable and explainable.
      @document.css("*").index(node) || Float::INFINITY
    end
  end
end

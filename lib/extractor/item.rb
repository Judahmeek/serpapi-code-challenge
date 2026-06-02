require "uri"

module Extractor
  # One carousel tile. We deliberately avoid pinning to volatile Google CSS
  # class names (`pgNMRc`, `cxzHyb`, ...) and instead navigate by structure:
  #   - the tile is built around a single <a href="/search?...">
  #   - the <img> alt attribute carries the canonical name
  #   - direct text-node descendants under the anchor that are not the name
  #     are treated as extensions (year, medium, etc.)
  class Item
    GOOGLE_BASE = "https://www.google.com".freeze

    # Class-level convenience API for callers.
    def self.parse(node, thumbnails:)
      new(node, thumbnails).to_h
    end

    def initialize(node, thumbnails)
      @node = node
      @thumbnails = thumbnails
      @anchor = node.matches?("a[href]") ? node : node.at_css("a[href]")
      @img = node.at_css("img")
    end

    def to_h
      # Minimum contract: without name, tile isn't usable.
      return nil unless name

      {
        "name" => name,
        "extensions" => extensions,
        "link" => link,
        "image" => image,
      }
    end

    private

    def name
      @name ||= begin
        # Ordered fallback chain:
        # 1) <img alt> is usually canonical title on Google tiles.
        # 2) aria-label/title cover accessibility or layout variants.
        # 3) first text block is a final rescue for unusual markup.
        candidates = [
          @img && @img["alt"],
          @node["title"],
          @node["aria-label"],
        ]
        result = candidates.map { |c| c && c.strip }.find { |c| c && !c.empty? }
        if result.nil?
          title = @node.at_css("[title]")
          aria = @node.at_css("[aria-label]")
          candidates = [
            title && title["title"],
            aria && aria["aria-label"],
            first_text_block,
          ]
          result = candidates.map { |c| c && c.strip }.find { |c| c && !c.empty? }
        end
        result
      end
    end

    # Anything under the anchor that isn't the name. We deliberately walk only
    # *leaf* elements (no element children) so we don't capture container text
    # that concatenates name + extension (e.g., "The Starry Night1889").
    # An array is preserved to keep parity with the SerpApi schema even when
    # Google adds extra chips (e.g., medium, location).
    def extensions
      # Leaf-only text prevents container text like "Name1889" from leaking in.
      leaves = @node.css("div, span").reject { |n| n.element_children.any? }
      texts = leaves.map { |n| n.text.strip }.reject(&:empty?).uniq
      # Remove duplicated title if it appears as a chip.
      texts.delete(name)
      texts.reject! { |t| t.length > 80 } # guard against accidental block grabs
      return nil if texts.empty?
      texts
    end

    def link
      return nil unless @anchor
      href = @anchor["href"].to_s
      # Keep existing absolute URLs unchanged.
      return href if href.start_with?("http")
      # Normalize relative Google paths so consumers get absolute links.
      URI.join(GOOGLE_BASE, href).to_s
    end

    # Resolution order matters:
    #   1. ThumbnailIndex lookup by <img id> — Google ships the real base64
    #      image via inline JS; the <img src> is a 1x1 transparent GIF
    #      placeholder until that JS runs.
    #   2. In-file attributes (`data-src`, then `src`) for non-placeholder
    #      data URIs.
    #   3. In-file URL thumbnails (`data-src` or `src`) when present.
    #
    # Requirement fit: the requirements asks for thumbnails present in the result
    # page file without extra requests. `data-src=https://...` values qualify
    # because they are already in the HTML snapshot.
    def image
      return nil unless @img

      # Primary path: image id resolved from inline JS mapping.
      from_index = @img["id"] && @thumbnails[@img["id"]]
      return from_index if from_index

      data_src = @img["data-src"].to_s
      src = @img["src"].to_s

      return data_src if data_src.start_with?("data:") && !placeholder?(data_src)
      # Accept inline non-placeholder data only.
      return src if src.start_with?("data:") && !placeholder?(src)

      [data_src, src].each do |candidate|
        return candidate if candidate.start_with?("http://", "https://")
      end

      nil
    end

    # 1x1 transparent GIF Google uses as the pre-hydration placeholder.
    PLACEHOLDER_PREFIX = "data:image/gif;base64,R0lGOD".freeze
    def placeholder?(src)
      src.start_with?(PLACEHOLDER_PREFIX)
    end

    def first_text_block
      # Fallback used only when stronger name signals are missing.
      @node.xpath(".//text()").map(&:to_s).map(&:strip).find { |t| !t.empty? }
    end
  end
end

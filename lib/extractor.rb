require "nokolexbor"

require_relative "extractor/thumbnail_index"
require_relative "extractor/carousel"
require_relative "extractor/item"

module Extractor
  # Public facade. Returns an Array<Hash> of carousel items.
  #
  # Why this shape:
  # - Callers only need one method (`Extractor.call`) and don't manage objects.
  # - Internally we still use small classes for focused responsibilities.
  # 
  #   Extractor.call("files/van-gogh-paintings.html")
  #   # => [{ "name" => "The Starry Night", "extensions" => ["1889"], ... }, ...]
  # Accepts either a file path string or raw HTML string.
  def self.call(html_or_path)
    # Support both CLI/file use and test/raw-html use with one entrypoint.
    html = if File.file?(html_or_path.to_s)
      File.read(html_or_path)
    else
      html_or_path
    end

    # Parse once into DOM, then build the thumbnail map once.
    # This avoids repeatedly scanning <script> nodes for every tile.
    document = Nokolexbor::HTML(html)
    thumbnails = ThumbnailIndex.build(document)

    # Keep parse pipeline explicit:
    # 1) find best carousel tiles
    # 2) parse each tile
    # 3) drop malformed/nil rows
    Carousel.tiles(document).map do |tile|
      Item.parse(tile, thumbnails: thumbnails)
    end.compact
  end
end

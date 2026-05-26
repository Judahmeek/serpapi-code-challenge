# frozen_string_literal: true

require 'zeitwerk'
require 'nokogiri'
require 'logger'
require 'uri'
require 'json'

loader = Zeitwerk::Loader.new
loader.push_dir(__dir__)
loader.setup

# Top-level namespace for the Google Carousel extractor.
module GoogleCarousel
  DEFAULT_CONFIG = CarouselConfig.new(
    section_finder: ->(doc) { doc.at_css('#search') },
    # Known data-attrid values: kc:/visual_art/visual_artist:works (artworks),
    #   kc:/people/person:movies (filmography), kc:/music/artist:albums (discography)
    carousel_finder: ->(section) { section.css('div').find { |d| d['data-attrid']&.start_with?('kc:/') } },
    item_selector: 'div > a',
    name_extractor: lambda { |node|
      (node.at_css('img + div div:first-child') ||
       node.at_css('wp-grid-tile div:nth-child(2) div:first-child'))&.text&.strip
    },
    extension_extractor: lambda { |node|
      (node.at_css('img + div') ||
       node.at_css('wp-grid-tile div:nth-child(2)'))
      &.css('div:nth-child(n+2)')
      &.map { |e| e.text.strip }
      &.reject(&:empty?) || []
    },
    link_extractor: ->(node) { node['href'] }
  )
end

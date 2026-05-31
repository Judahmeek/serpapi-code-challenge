# frozen_string_literal: true

require 'nokolexbor'

# Top-level namespace for the Google Carousel extractor.
module CustomCarousel
  extend self
  CarouselItem = Data.define(:name, :extensions, :link, :image)

  # this method has been changed; all other methods are the same
  def section_finder(doc)
    doc.at_css('#custom-section')
  end

  def carousel_finder(section)
    section.css('div').find { |d| d['data-attrid']&.start_with?('kc:/') }
  end

  def item_selector
    'div > a'
  end

  def name_extractor(node)
    (node.at_css('img + div div:first-child') ||
      node.at_css('wp-grid-tile div:nth-child(2) div:first-child'))&.text&.strip
  end

  def extension_extractor(node)
    (node.at_css('img + div') ||
      node.at_css('wp-grid-tile div:nth-child(2)'))
    &.css('div:nth-child(n+2)')
    &.map { |e| e.text.strip }
    &.reject(&:empty?) || []
  end

  def link_extractor(node)
    node['href']
  end
end

# frozen_string_literal: true

require 'nokolexbor'

# Top-level namespace for the Google Carousel extractor.
module GoogleCarousel
  extend self
  CarouselItem = Data.define(:name, :extensions, :link, :image)

  def section_finder(doc)
    doc.at_css('#search')
  end
  # Known data-attrid values that do not start with 'kc:' -> RecentPresidents
  def carousel_finder(section)
    section.css('div').find { |d| d['data-attrid'] }
  end

  def item_selector
    'div > a' # Won't work for interactive results like 'tom cruise films' (vs 'tom cruise filmography')
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

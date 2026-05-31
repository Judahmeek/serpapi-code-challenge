# frozen_string_literal: true
require 'nokolexbor'
require 'logger'

require_relative 'image_resolver'
require_relative 'item_extractor'
require_relative 'json_serializer'

class ParseError < StandardError; end

# Top-level orchestrator: takes HTML, locates the carousel section and container
# via config finders, and extracts each carousel item via ItemExtractor + ImageResolver.
class Parser
  def initialize(config: nil, logger: Logger.new($stdout))
    @config = config
    @logger = logger
  end

  def parse(html, base_url: nil, serialize_to_json: false)
    raise ParseError, 'No config initialized' if @config.nil?
    document       = Nokolexbor::HTML(html)
    item_extractor = ItemExtractor.new(@config, ImageResolver.new(document), base_url: base_url)
    items          = find_items(document)

    @logger.info("Found #{items.size} carousel items")

    extracted_items = items.map.with_index(1) do |node, i|
      item = item_extractor.extract(node)
      @logger.debug("Item #{i}: #{item.name.inspect}")
      item
    end

    serialize_to_json ? JsonSerializer.new(extracted_items).to_json : extracted_items
  end

  private

  def find_items(document)
    section  = @config.section_finder(document) or raise ParseError, 'Carousel section not found'
    carousel = @config.carousel_finder(section) or
      raise ParseError, 'Carousel container not found within section'

    @logger.debug("Carousel container: data-attrid=#{carousel['data-attrid'].inspect}")
    items = carousel.css(@config.item_selector)
    raise ParseError, "No carousel items found (selector: #{@config.item_selector.inspect})" if items.empty?

    items
  end
end

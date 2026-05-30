# frozen_string_literal: true

# Extracts a CarouselItem from a single item node by delegating to the
# configured extractor lambdas and resolving the link against an optional
# base URL. Image resolution is delegated to the injected ImageResolver
# and skipped when the node has no <img> child.
class ItemExtractor
  SAFE_LINK_SCHEMES = %w[http https].freeze

  def initialize(config, image_resolver, base_url: nil)
    @config         = config
    @image_resolver = image_resolver
    @base_url       = base_url
  end

  def extract(node)
    img      = node.at_css('img')
    raw_link = @config.link_extractor.call(node)
    CarouselItem.new(
      name: @config.name_extractor.call(node),
      extensions: @config.extension_extractor.call(node),
      link: resolve_url(raw_link),
      image: img ? @image_resolver.resolve(img) : nil
    )
  end

  private

  def resolve_url(href)
    return nil if href.nil?
    return href if @base_url.nil? || @base_url.empty?

    joined = URI.join(@base_url, href).to_s
    SAFE_LINK_SCHEMES.include?(URI.parse(joined).scheme) ? joined : nil
  rescue URI::InvalidURIError, URI::BadURIError
    href
  end
end

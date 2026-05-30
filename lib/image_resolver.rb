# frozen_string_literal: true

# Resolves the best image string for an <img> node by checking, in order:
# inline base64 embedded in <script> blocks, the data-src attribute, and
# finally a non-placeholder src attribute.
class ImageResolver
  SAFE_IMAGE_PREFIXES = %w[https:// http:// data:image/].freeze

  def initialize(document)
    @image_map = build_image_map(document)
  end

  def resolve(img_node)
    @image_map[img_node['id']] ||
      safe_image_url(img_node['data-src']) ||
      non_placeholder_src(img_node['src'])
  end

  private

  def build_image_map(document)
    pattern = %r{var s='(data:image/[^']+)';var ii=\[([^\]]+)\]}
    document.css('script').each_with_object({}) do |script, map|
      script.text.scan(pattern) do |data, ids_str|
        ids_str.scan(/'([^']+)'/) { |id,| map[id] = unescape_js(data) }
      end
    end
  end

  def safe_image_url(url)
    url if url && SAFE_IMAGE_PREFIXES.any? { |p| url.start_with?(p) }
  end

  # Decodes JS \xHH hex escapes embedded in Google's inline image strings
  # (e.g. trailing base64 padding "=" is often written as "\x3d").
  def unescape_js(string)
    string.gsub(/\\x([0-9A-Fa-f]{2})/) { Regexp.last_match(1).hex.chr(Encoding::UTF_8) }
  end

  def non_placeholder_src(src)
    return nil unless safe_image_url(src)
    return nil if src.start_with?('data:image/gif;base64')

    src
  end
end

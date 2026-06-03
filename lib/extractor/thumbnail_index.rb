module Extractor
  # Google ships inline thumbnails as JS blocks of the shape:
  #
  #   (function(){var s='data:image/jpeg;base64,...';
  #    var ii=['_id1','_id2'];var r='';_setImagesSrc(ii,s,r);})();
  #
  # The visible <img> tag's `src` is just a 1x1 GIF placeholder; the real
  # thumbnail is injected at runtime against the image id(s) listed in `ii`.
  # We replicate that mapping at parse time so no JS execution is required.
  class ThumbnailIndex
    ID_REGEX = /'([^']+)'/.freeze

    # Public convenience API.
    def self.build(document)
      new(document).build
    end

    def initialize(document)
      @document = document
    end

    def build
      # scrapeMemo psuedocode: if the Carousel class detected a relevant scrapeMemo index, then the recorded function name, variable names, and variable order (maybe?) could be used to construct a single regex instead of the three different regexes I'm using
      image_setter_regex = /_setImagesSrc\((?<id>[a-z]*),\s*(?<source>[a-z]*)/.freeze
      mapping = {}
      @document.css("script").each do |script|
        body = script.content
        desired_variables = body.match(image_setter_regex)
        # instead of skipping if the image_setter_regex fails to match because the image_setter function has been renamed, we could modify the source & ids regexes to look for properly formatted variable assignments & then look for a function taking those variables as parameters near the very end of the script
        # Something like...
        # source_regex = /var\s+(?<source_variable>\w+)\s*=\s*'(?<data>data:image\/[^']+)'\s*;/.freeze
        # ids_regex = /var\s+(?<ids_variable>\w+)\s*=\s*\[(?<ids>[^\]]*)\]\s*;/.freeze
        # image_setter_regex = /(?<function_name>\w+)\((#{source_variable}|#{ids_variable}),\s*(#{source_variable}|#{ids_variable}).{,12}\z/.freeze
        next if desired_variables.nil?

        source_regex = /var\s+#{desired_variables[:source]}\s*=\s*'(?<data>data:image\/[^']+)'\s*;/.freeze
        ids_regex = /var\s+#{desired_variables[:id]}\s*=\s*\[(?<ids>[^\]]*)\]\s*;/.freeze

        source_result = body.match(source_regex)
        ids_result = body.match(ids_regex)

        # Decode JS escapes so the resulting data URI matches browser output.
        data_uri = unescape_js(source_result[:data])
        # One data URI can map to multiple image ids.
        ids_result[:ids].scan(ID_REGEX) { |(id)| mapping[id] = data_uri }
      end
      mapping
    end

    private

    # Google's inline JS escapes the trailing `=` of base64 padding as `\x3d`
    # (and slashes as `\/`). We undo the minimal set of escapes that show up
    # in practice — enough to make the resulting data URI byte-identical to
    # what a browser would render after _setImagesSrc runs.
    def unescape_js(str)
      str.gsub(/\\x([0-9a-fA-F]{2})/) { [$1.to_i(16)].pack("C") }
         .gsub('\\/', "/")
         .gsub("\\\\", "\\")
    end
  end
end

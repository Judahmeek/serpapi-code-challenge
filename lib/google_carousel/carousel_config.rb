# frozen_string_literal: true

module GoogleCarousel
  CarouselConfig = Data.define(
    :section_finder,       # callable(document) → section_node
    :carousel_finder,      # callable(section_node) → carousel_div_node
    :item_selector,        # CSS selector for items within carousel: 'div > a'
    :name_extractor,       # callable(item_node) → String | nil
    :extension_extractor,  # callable(item_node) → Array<String>
    :link_extractor        # callable(item_node) → String (raw href; URL resolution handled by ItemExtractor)
  )
end

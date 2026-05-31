# frozen_string_literal: true

require 'json'

class JsonSerializer
  def initialize(items, root_key: 'artworks')
    @items    = items
    @root_key = root_key
  end

  def to_json(*)
    JSON.generate(@root_key => @items.map { |item| serialize(item) })
  end

  private

  def serialize(item)
    item.to_h.reject { |_, v| v.nil? || v == [] }
  end
end

require_relative '../lib/json_serializer'
require 'json'

RSpec.describe JsonSerializer do
  let(:item_with_ext) do
    GoogleCarousel::CarouselItem.new(
      name:       'The Starry Night',
      extensions: ['1889'],
      link:       '/search?q=starry',
      image:      'data:image/jpeg;base64,abc'
    )
  end

  let(:item_without_ext) do
    GoogleCarousel::CarouselItem.new(
      name:       'Wheat Field',
      extensions: [],
      link:       '/search?q=wheat',
      image:      nil
    )
  end

  describe '#to_json' do
    it 'wraps items under the default root key "artworks"' do
      result = described_class.new([item_with_ext]).to_json
      expect(JSON.parse(result).keys).to eq(['artworks'])
    end

    it 'respects a custom root key' do
      result = described_class.new([item_with_ext], root_key: 'paintings').to_json
      expect(JSON.parse(result).keys).to eq(['paintings'])
    end

    it 'includes extensions when non-empty' do
      parsed = JSON.parse(described_class.new([item_with_ext]).to_json)
      expect(parsed['artworks'].first['extensions']).to eq(['1889'])
    end

    it 'omits extensions when empty' do
      parsed = JSON.parse(described_class.new([item_without_ext]).to_json)
      expect(parsed['artworks'].first).not_to have_key('extensions')
    end

    it 'omits nil fields' do
      parsed = JSON.parse(described_class.new([item_without_ext]).to_json)
      expect(parsed['artworks'].first).not_to have_key('image')
    end

    it 'does not omit filled extensions' do
      parsed = JSON.parse(described_class.new([item_with_ext]).to_json)
      expect(parsed['artworks'].first).to have_key('extensions')
    end

    it 'does not omit filled fields' do
      parsed = JSON.parse(described_class.new([item_with_ext]).to_json)
      expect(parsed['artworks'].first).to have_key('image')
    end
  end
end

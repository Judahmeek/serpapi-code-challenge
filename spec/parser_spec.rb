require_relative '../lib/parser'
require_relative '../lib/google_carousel'
require_relative './fixtures/custom_carousel'

FILES_DIR    = File.join(__dir__, '..', 'files')
HTML         = File.read(File.join(FILES_DIR, 'van-gogh-paintings.html'))
EXPECTED     = File.read(File.join(FILES_DIR, 'expected-array.json'))
FIXTURES_DIR = File.join(__dir__, 'fixtures')
MOVIES_HTML  = File.read(File.join(FIXTURES_DIR, 'movies_carousel.html'))
BOOKS_HTML   = File.read(File.join(FIXTURES_DIR, 'books_carousel.html'))

RSpec.describe Parser do
  let(:parser) { described_class.new(config: GoogleCarousel, logger: Logger.new(File::NULL)) }

  describe '#parse — Van Gogh paintings partial integration' do
    subject(:items) { parser.parse(HTML, base_url: 'https://www.google.com') }

    let(:expected_items) do
      JSON.parse(EXPECTED)['artworks'].map { |a| { extensions: [] }.merge(a.transform_keys(&:to_sym)) }
    end

    it 'returns 47 items' do
      expect(items.count).to eq(47)
    end

    it 'matches all items in the expected array exactly' do
      expect(items.map(&:to_h)).to eq(expected_items)
    end
  end

  describe '#parse — Van Gogh paintings full integration' do
    subject(:result) { parser.parse(HTML, base_url: 'https://www.google.com', serialize_to_json: true) }

    it 'matches all items in the expected array exactly' do
      expect(JSON.parse(result)).to eq(JSON.parse(EXPECTED))
    end
  end

  describe '#parse — movies fixture (Layout B)' do
    subject(:items) { parser.parse(MOVIES_HTML) }

    it 'returns 3 items' do
      expect(items.count).to eq(3)
    end

    it 'extracts correct names' do
      expect(items.map(&:name)).to eq(['Movie One', 'Movie Two', 'Movie Three'])
    end

    it 'extracts correct extensions' do
      expect(items.map(&:extensions)).to eq([['2001'], ['2002'], ['2003']])
    end

    it 'extracts correct links' do
      expect(items.map(&:link)).to eq(['/search?q=movie1', '/search?q=movie2', '/search?q=movie3'])
    end

    it 'extracts correct images' do
      expect(items.map(&:image)).to eq(
        ['https://example.com/m1.jpg', 'https://example.com/m2.jpg', 'https://example.com/m3.jpg']
      )
    end
  end

  describe '#parse — books fixture (Layout A)' do
    subject(:items) { parser.parse(BOOKS_HTML) }

    it 'returns 3 items' do
      expect(items.count).to eq(3)
    end

    it 'extracts correct names' do
      expect(items.map(&:name)).to eq(['Book One', 'Book Two', 'Book Three'])
    end

    it 'extracts correct extensions' do
      expect(items.map(&:extensions)).to eq([['2010'], ['2011'], ['2012']])
    end

    it 'extracts correct links' do
      expect(items.map(&:link)).to eq(['/search?q=book1', '/search?q=book2', '/search?q=book3'])
    end

    it 'extracts correct images' do
      expect(items.map(&:image)).to eq(
        ['https://example.com/b1.jpg', 'https://example.com/b2.jpg', 'https://example.com/b3.jpg']
      )
    end
  end

  describe '#parse — error cases' do
    let(:no_section_html) { '<html><body><div id="other"></div></body></html>' }
    let(:no_carousel_html) do
      '<html><body><div id="search"><div>no attrid here</div></div></body></html>'
    end
    let(:no_items_html) do
      '<html><body><div id="search"><div data-attrid="kc:/test"><p>not a div>a</p></div></div></body></html>'
    end

    it 'raises ParseError when the search section is missing' do
      expect { parser.parse(no_section_html) }
        .to raise_error(ParseError, 'Carousel section not found')
    end

    it 'raises ParseError when the carousel container is missing' do
      expect { parser.parse(no_carousel_html) }
        .to raise_error(ParseError, 'Carousel container not found within section')
    end

    it 'raises ParseError when no carousel items are found' do
      expect { parser.parse(no_items_html) }
        .to raise_error(ParseError, /No carousel items found/)
    end
  end

  describe '#parse — configurability' do
    let(:custom_html) do
      '<html><body><div id="custom-section"><div data-attrid="kc:/test">' \
        '<div><a href="/item"><img src="x.jpg"/><div><div>Custom Item</div></div></a></div>' \
        '</div></div></body></html>'
    end

    let(:custom_parser) { described_class.new(config: CustomCarousel, logger: Logger.new(File::NULL)) }

    it 'uses the custom section_finder from a derived config' do
      expect(custom_parser.parse(custom_html).first.name).to eq('Custom Item')
    end
  end
end

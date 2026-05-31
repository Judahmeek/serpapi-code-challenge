require 'nokolexbor'

require_relative '../lib/item_extractor'

RSpec.describe ItemExtractor do
  let(:config) { GoogleCarousel }

  def make_node(html)
    Nokolexbor::HTML(html).at_css('a')
  end

  def stub_resolver(image_value = nil)
    resolver = instance_double(ImageResolver)
    allow(resolver).to receive(:resolve).and_return(image_value)
    resolver
  end

  let(:well_formed_html) do
    <<~HTML
      <html><body>
        <a href="/search?q=test">
          <img id="img1" src="data:image/gif;base64,placeholder" />
          <div>
            <div>Test Item</div>
            <div>2020</div>
          </div>
        </a>
      </body></html>
    HTML
  end

  let(:well_formed_layout_b_html) do
    <<~HTML
      <html><body>
        <a href="/search?q=test-b">
          <wp-grid-tile>
            <div><img src="https://example.com/photo.jpg" /></div>
            <div>
              <div>Layout B Item</div>
              <div>2023</div>
            </div>
          </wp-grid-tile>
        </a>
      </body></html>
    HTML
  end

  describe '#extract' do
    it 'resolves relative href to absolute URL when base_url is provided' do
      node      = make_node(well_formed_html)
      extractor = described_class.new(config, stub_resolver, base_url: 'https://www.google.com')
      item      = extractor.extract(node)
      expect(item.link).to eq('https://www.google.com/search?q=test')
    end

    it 'returns raw href when base_url is nil' do
      node      = make_node(well_formed_html)
      extractor = described_class.new(config, stub_resolver)
      item      = extractor.extract(node)
      expect(item.link).to eq('/search?q=test')
    end

    it 'returns nil name when name node is absent' do
      html      = '<html><body><a href="/x"><img /><div></div></a></body></html>'
      node      = make_node(html)
      extractor = described_class.new(config, stub_resolver)
      item      = extractor.extract(node)
      expect(item.name).to be_nil
    end

    it 'returns empty array when extension nodes are absent' do
      html      = '<html><body><a href="/x"><img /><div><div>Name Only</div></div></a></body></html>'
      node      = make_node(html)
      extractor = described_class.new(config, stub_resolver)
      item      = extractor.extract(node)
      expect(item.extensions).to eq([])
    end

    it 'returns nil image when node has no img element' do
      html      = '<html><body><a href="/x"><div><div>Name</div></div></a></body></html>'
      node      = make_node(html)
      extractor = described_class.new(config, stub_resolver)
      item      = extractor.extract(node)
      expect(item.image).to be_nil
    end

    it 'extracts name from Layout B (wp-grid-tile) node' do
      node      = make_node(well_formed_layout_b_html)
      extractor = described_class.new(config, stub_resolver('https://example.com/photo.jpg'))
      item      = extractor.extract(node)
      expect(item.name).to eq('Layout B Item')
    end

    it 'extracts extensions from Layout B (wp-grid-tile) node' do
      node      = make_node(well_formed_layout_b_html)
      extractor = described_class.new(config, stub_resolver)
      item      = extractor.extract(node)
      expect(item.extensions).to eq(['2023'])
    end

    it 'returns raw href when URI.join raises on a malformed href' do
      html      = '<html><body><a href="  bad uri"><img /><div><div>Name</div></div></a></body></html>'
      node      = make_node(html)
      extractor = described_class.new(config, stub_resolver, base_url: 'https://www.google.com')
      item      = extractor.extract(node)
      expect(item.link).to eq('  bad uri')
    end

    it 'returns raw href when base_url is an empty string' do
      node      = make_node(well_formed_html)
      extractor = described_class.new(config, stub_resolver, base_url: '')
      item      = extractor.extract(node)
      expect(item.link).to eq('/search?q=test')
    end

    it 'returns nil when the resolved href has a non-http(s) scheme' do
      html      = '<html><body><a href="data:text/html,evil"><img /><div><div>Name</div></div></a></body></html>'
      node      = make_node(html)
      extractor = described_class.new(config, stub_resolver, base_url: 'https://www.google.com')
      item      = extractor.extract(node)
      expect(item.link).to be_nil
    end
  end
end

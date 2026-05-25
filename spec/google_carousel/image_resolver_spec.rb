RSpec.describe GoogleCarousel::ImageResolver do
  def make_document(html)
    Nokogiri::HTML(html)
  end

  describe '#resolve' do
    context 'inline base64 from script block' do
      it 'returns the base64 string when img id matches' do
        html = <<~HTML
          <html><body>
          <script>var s='data:image/jpeg;base64,abc123';var ii=['kimg0']</script>
          <img id="kimg0" src="data:image/gif;base64,placeholder" />
          </body></html>
        HTML
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to eq('data:image/jpeg;base64,abc123')
      end

      it 'falls through to data-src when img id is absent from image map' do
        html = <<~HTML
          <html><body>
          <script>var s='data:image/jpeg;base64,abc123';var ii=['kimg0']</script>
          <img id="kimg99" data-src="https://cdn.example.com/photo.jpg" src="data:image/gif;base64,placeholder" />
          </body></html>
        HTML
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to eq('https://cdn.example.com/photo.jpg')
      end
    end

    context 'data-src attribute' do
      it 'returns the data-src URL' do
        html     = '<html><body><img data-src="https://cdn.example.com/photo.jpg" src="data:image/gif;base64,p" /></body></html>'
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to eq('https://cdn.example.com/photo.jpg')
      end
    end

    context 'src attribute' do
      it 'returns nil when src is a placeholder GIF' do
        html     = '<html><body><img src="data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==" /></body></html>'
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to be_nil
      end

      it 'returns src when it is a real non-GIF URL' do
        html     = '<html><body><img src="https://example.com/real.jpg" /></body></html>'
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to eq('https://example.com/real.jpg')
      end

      it 'returns nil when neither inline base64, data-src, nor real src are present' do
        html     = '<html><body><img /></body></html>'
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to be_nil
      end
    end

    context 'multiple script blocks' do
      it 'builds the correct id-to-image mapping from all scripts' do
        html = <<~HTML
          <html><body>
          <script>var s='data:image/jpeg;base64,img1data';var ii=['id1']</script>
          <script>var s='data:image/jpeg;base64,img2data';var ii=['id2']</script>
          <img id="id2" src="data:image/gif;base64,placeholder" />
          </body></html>
        HTML
        doc      = make_document(html)
        img      = doc.at_css('img')
        resolver = described_class.new(doc)
        expect(resolver.resolve(img)).to eq('data:image/jpeg;base64,img2data')
      end
    end
  end
end

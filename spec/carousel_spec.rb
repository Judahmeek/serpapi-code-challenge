require "nokolexbor"

RSpec.describe Extractor::Carousel do
  def doc_for(html)
    Nokolexbor::HTML(html)
  end

  context "when sizes tie" do
    it "prioritizes image elements with alt attributes over elements with title attributes" do
      doc = doc_for(<<~HTML)
        <html><body>
          <div id="title">
            <div><div title="one"></div><img></a></div>
            <div><div title="two"></div><img></a></div>
            <div><div title="three"></div><img></a></div>
          </div>
          <div id="alt">
            <div><img alt="S1"></div>
            <div><img alt="S2"></div>
            <div><img alt="S3"></div>
          </div>
        </body></html>
      HTML

      tiles = described_class.tiles(doc)
      expect(tiles.size).to eq(3)
      expect(tiles.first.parent["id"]).to eq("alt")
    end

    it "prioritizes elements with title attributes over aria-labels" do
      doc = doc_for(<<~HTML)
        <html><body>
          <div id="aria">
            <div><div aria-label="one"></div><img></a></div>
            <div><div aria-label="two"></div><img></a></div>
            <div><div aria-label="three"></div><img></a></div>
          </div>
          <div id="title">
            <div><div title="one"></div><img></a></div>
            <div><div title="two"></div><img></a></div>
            <div><div title="three"></div><img></a></div>
          </div>
        </body></html>
      HTML

      tiles = described_class.tiles(doc)
      expect(tiles.size).to eq(3)
      expect(tiles.first.parent["id"]).to eq("title")
    end

    it "is deterministic on exact ties by picking the first group in DOM order" do
      doc = doc_for(<<~HTML)
        <html><body>
          <div id="first">
            <div><a href="/search?stick=f1"><img alt="F1"></a></div>
            <div><a href="/search?stick=f2"><img alt="F2"></a></div>
            <div><a href="/search?stick=f3"><img alt="F3"></a></div>
          </div>
          <div id="second">
            <div><a href="/search?stick=s1"><img alt="S1"></a></div>
            <div><a href="/search?stick=s2"><img alt="S2"></a></div>
            <div><a href="/search?stick=s3"><img alt="S3"></a></div>
          </div>
        </body></html>
      HTML

      tiles = described_class.tiles(doc)
      expect(tiles.size).to eq(3)
      expect(tiles.first.parent["id"]).to eq("first")
    end
  end

  describe "group score & quality weights" do
    it "prefers the candidate group with stronger tile signals when sizes are close" do
      doc = doc_for(<<~HTML)
          <div id="quantity">
            <div><a href="/search?stick=f1"></a></div>
            <div><a href="/search?stick=f2"></a></div>
            <div><a href="/search?stick=f3"></a></div>
            <div><a href="/search?stick=f4"></a></div>
            <div><a href="/search?stick=f5"></a></div>
            <div><a href="/search?stick=f6"></a></div>
          </div>
          <div id="quality">
            <div><a href="/search?stick=s1"><img alt="S1"></a></div>
            <div><a href="/search?stick=s2"><img alt="S2"></a></div>
            <div><a href="/search?stick=s3"><img alt="S3"></a></div>
            <div><a href="/search?stick=s4"><img alt="S4"></a></div>
            <div><a href="/search?stick=f5"><img alt="S5"></a></div>
          </div>
        </body></html>
      HTML

      tiles = described_class.tiles(doc)
      expect(tiles.size).to eq(5)
      expect(tiles.first.parent["id"]).to eq("quality")
    end

    it "the ACCEPTABLE_NUMBER_OF_MISFORMED_TILES environment variable can soften the uniformity requirement" do
      allow(ENV).to receive(:fetch).and_call_original # Preserves unmocked keys
      allow(ENV).to receive(:fetch).with("ACCEPTABLE_NUMBER_OF_MISFORMED_TILES", 0).and_return("2")
      doc = doc_for(<<~HTML)
          <div id="quantity">
            <div><a href="/search?stick=f1"></a></div>
            <div><a href="/search?stick=f2"></a></div>
            <div><a href="/search?stick=f3"></a></div>
            <div><a href="/search?stick=f4"></a></div>
            <div><a href="/search?stick=f5"></a></div>
            <div><a href="/search?stick=f6"></a></div>
          </div>
          <div id="quality">
            <div><a href="/search?stick=s1"><img alt="S1"></a></div>
            <div><a href="/search?stick=s2"><img alt="S2"></a></div>
            <div><a href="/search?stick=s3"><img alt="S3"></a></div>
            <div><a href="/search?stick=s4"></a></div>
            <div><a href="/search?stick=f5"></a></div>
          </div>
        </body></html>
      HTML

      tiles = described_class.tiles(doc)
      expect(tiles.size).to eq(5)
      expect(tiles.first.parent["id"]).to eq("quality")
    end
  end

  it "selects anchor elements if easily detectable name candidates can't be found" do
    doc = doc_for(<<~HTML)
      <html><body>
        <div id="stick">
          <div><a href="/search?stick=f2"><img></a></div>
          <div><a href="/search?stick=f2"><img></a></div>
          <div><a href="/search?stick=f3"><img></a></div>
        </div>
      </body></html>
    HTML

    tiles = described_class.tiles(doc)
    expect(tiles.size).to eq(3)
    expect(tiles.first.parent["id"]).to eq("stick")
  end
end

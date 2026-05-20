require "nokogiri"

RSpec.describe Extractor::Carousel do
  def doc_for(html)
    Nokogiri::HTML(html)
  end

  it "prefers the candidate group with stronger tile signals when sizes tie" do
    doc = doc_for(<<~HTML)
      <html><body>
        <div id="weak">
          <div><a href="/search?stick=w1">One</a></div>
          <div><a href="/search?stick=w2">Two</a></div>
          <div><a href="/search?stick=w3">Three</a></div>
        </div>
        <div id="strong">
          <div><a href="/search?stick=s1"><img alt="S1"><span>2001</span></a></div>
          <div><a href="/search?stick=s2"><img alt="S2"><span>2002</span></a></div>
          <div><a href="/search?stick=s3"><img alt="S3"><span>2003</span></a></div>
        </div>
      </body></html>
    HTML

    tiles = described_class.tiles(doc)
    expect(tiles.size).to eq(3)
    expect(tiles.first.parent["id"]).to eq("strong")
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

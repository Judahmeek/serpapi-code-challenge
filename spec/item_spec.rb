require "nokolexbor"

RSpec.describe Extractor::Item do
  def tile_from(html)
    document = Nokolexbor::Document.new
    document.fragment(html).at_css("div")
  end

  it "extracts name from img alt and absolutizes the link" do
    node = tile_from(<<~HTML)
      <div>
        <a href="/search?q=Foo&stick=abc">
          <img alt="Foo" id="img1">
          <div><div>1889</div></div>
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: { "img1" => "data:image/jpeg;base64,AA" })
    expect(out["name"]).to eq("Foo")
    expect(out["link"]).to eq("https://www.google.com/search?q=Foo&stick=abc")
    expect(out["extensions"]).to eq(["1889"])
    expect(out["image"]).to eq("data:image/jpeg;base64,AA")
  end

  it "drops the placeholder 1x1 GIF in favor of the index" do
    placeholder = "data:image/gif;base64,R0lGODlhAQABAIAAAP///////yH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="
    node = tile_from(<<~HTML)
      <div>
        <a href="/search?stick=1">
          <img alt="Bar" id="img2" src="#{placeholder}">
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: { "img2" => "data:image/jpeg;base64,REAL" })
    expect(out["image"]).to eq("data:image/jpeg;base64,REAL")
  end

  it "skips container text so extensions aren't polluted by name+ext concatenation" do
    node = tile_from(<<~HTML)
      <div>
        <a href="/search?stick=2">
          <img alt="Starry" id="i">
          <div class="wrapper">
            <div>Starry</div>
            <div>1889</div>
          </div>
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: {})
    expect(out["extensions"]).to eq(["1889"])
  end

  it "returns nil when there is no anchor (malformed tile)" do
    node = tile_from("<div><span>just text</span></div>")
    expected = {"extensions" => nil, "image" => nil, "link" => nil, "name" => "just text"}
    expect(described_class.parse(node, thumbnails: {})).to eq(expected)
  end

  it "falls back to aria-label when img alt is missing" do
    node = tile_from(<<~HTML)
      <div>
        <a aria-label="Fallback Name" href="/search?stick=3">
          <img id="x">
          <div><div>1901</div></div>
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: {})
    expect(out["name"]).to eq("Fallback Name")
    expect(out["extensions"]).to eq(["1901"])
  end

  it "prioritizes title over aria-label" do
    node = tile_from(<<~HTML)
      <div>
        <a title="The Better Choice" aria-label="Fallback Name" href="/search?stick=3">
          <img id="x">
          <div><div>1901</div></div>
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: {})
    expect(out["name"]).to eq("The Better Choice")
  end

  it "returns in-file thumbnail URL from data-src when present" do
    node = tile_from(<<~HTML)
      <div>
        <a href="/search?stick=4">
          <img alt="Remote" src="data:image/gif;base64,R0lGODlhAQABAIAAAP///////yH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==" data-src="https://example.com/remote.jpg">
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: {})
    expect(out["image"]).to eq("https://example.com/remote.jpg")
  end

  it "returns in-file thumbnail URL from src when it is already non-placeholder http(s)" do
    node = tile_from(<<~HTML)
      <div>
        <a href="/search?stick=5">
          <img alt="RemoteSrc" src="https://example.com/src.jpg">
        </a>
      </div>
    HTML
    out = described_class.parse(node, thumbnails: {})
    expect(out["image"]).to eq("https://example.com/src.jpg")
  end
end

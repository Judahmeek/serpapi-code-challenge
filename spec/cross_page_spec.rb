# Structural-invariant tests on two non-Van-Gogh carousel pages. These
# fixtures intentionally differ from the Van Gogh layout (different CSS
# class names, deeper anchor nesting, aria-label as the name source,
# missing-extension rows). The point is to prove the extractor doesn't
# silently regress against layout drift.

RSpec.describe "Extractor against non-Van-Gogh carousel pages" do
  describe "Frida Kahlo paintings (renamed classes, multi-id ii arrays)" do
    let(:result) { Extractor.call(File.expand_path("fixtures/frida-kahlo-paintings.html", __dir__)) }

    it "finds all five tiles" do
      expect(result.size).to eq(5)
    end

    it "extracts canonical painting names" do
      expect(result.map { |r| r["name"] }).to eq([
        "The Two Fridas",
        "Self-Portrait with Thorn Necklace and Hummingbird",
        "The Broken Column",
        "Henry Ford Hospital",
        "My Birth",
      ])
    end

    it "extracts the year as a single-element extensions array" do
      expect(result.map { |r| r["extensions"] }).to eq([["1939"], ["1940"], ["1944"], ["1932"], ["1932"]])
    end

    it "absolutizes every link to https://www.google.com" do
      expect(result.map { |r| r["link"] }).to all(start_with("https://www.google.com/search?"))
    end

    it "resolves inline thumbnails via the JS index, including multi-id blocks" do
      images = result.map { |r| r["image"] }
      expect(images[0]).to eq("data:image/jpeg;base64,FRIDA_BLOB_1")
      # Both tiles 2 and 3 are listed in the same `ii` array and should
      # resolve to the same blob — with the \x3d padding decoded.
      expect(images[1]).to eq("data:image/jpeg;base64,FRIDA_BLOB_2==")
      expect(images[2]).to eq("data:image/jpeg;base64,FRIDA_BLOB_2==")
      # Tiles 4 and 5 are lazy-loaded on a real SERP → no inline blob.
      expect(images[3]).to be_nil
      expect(images[4]).to be_nil
    end
  end

  describe "Nolan films (aria-label name, deeper nesting, missing ext)" do
    let(:result) { Extractor.call(File.expand_path("fixtures/nolan-films.html", __dir__)) }

    it "finds all five tiles" do
      expect(result.size).to eq(5)
    end

    it "extracts canonical film names" do
      expect(result.map { |r| r["name"] }).to eq([
        "Oppenheimer", "Inception", "Interstellar", "The Dark Knight", "Dunkirk"
      ])
    end

    it "captures year chips when present and nil when not (no crash on missing ext)" do
      ext = result.map { |r| r["extensions"] }
      expect(ext[0..3]).to eq([["2023"], ["2010"], ["2014"], ["2008"]])
      expect(ext[4]).to be_nil
    end
  end
end

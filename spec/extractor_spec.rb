require "json"

RSpec.describe Extractor do
  describe ".call with the Van Gogh fixture" do
    let(:expected) do
      JSON.parse(File.read(File.join(FIXTURES_DIR, "expected-array.json")))["artworks"]
    end
    let(:result) { Extractor.call(File.join(FIXTURES_DIR, "van-gogh-paintings.html")) }

    it "returns the same number of items as the SerpApi reference output" do
      expect(result.size).to eq(expected.size)
    end

    it "matches name, extensions and link byte-for-byte across all items" do
      mismatches = result.each_with_index.reject do |item, i|
        %w[name extensions link].all? { |f| item[f] == expected[i][f] }
      end
      expect(mismatches).to be_empty, -> {
        mismatches.first(3).map { |it, i|
          "row #{i}: got=#{it.reject { |k,_| k == 'image' }.inspect} " \
            "exp=#{expected[i].reject { |k,_| k == 'image' }.inspect}"
        }.join("\n")
      }
    end

    it "extracts every inline thumbnail present in the HTML exactly" do
      # The page only ships the first N base64 thumbnails inline. The rest
      # are URL thumbnails in in-file attributes (e.g. data-src). Those are
      # still part of the page snapshot and should be surfaced as-is.
      inline_expected = expected.each_with_index.select { |e, _| e["image"].to_s.start_with?("data:") }

      inline_expected.each do |e, i|
        expect(result[i]["image"]).to eq(e["image"]),
          "mismatch on row #{i} (#{e['name']})"
      end
    end

    it "matches image output byte-for-byte against expected array" do
      mismatches = result.each_with_index.reject { |item, i| item["image"] == expected[i]["image"] }
      expect(mismatches).to be_empty, -> {
        mismatches.first(3).map { |(item, i)|
          "row #{i}: got=#{item['image'].inspect} exp=#{expected[i]['image'].inspect}"
        }.join("\n")
      }
    end
  end
end

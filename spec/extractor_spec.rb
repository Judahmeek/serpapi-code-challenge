require "json"

RSpec.describe Extractor do
  describe ".call with the Van Gogh fixture" do
    let(:expected) do
      JSON.parse(File.read(File.join(FIXTURES_DIR, "expected-array.json")))["artworks"]
    end
    let(:result) { Extractor.call(File.join(FIXTURES_DIR, "van-gogh-paintings.html")) }

    it "matches SerpApi reference output" do
      expect(result).to eq(expected)
    end
  end

  describe ".call with U.S. Presidents fixture" do
    let(:expected) do
      JSON.parse(File.read((File.expand_path("fixtures/u.s._presidents.json", __dir__))))["artworks"]
    end
    let(:result) { Extractor.call(File.expand_path("fixtures/u.s._presidents.html", __dir__)) }

    it "matches U.S. Presidents reference output" do
      expect(result).to eq(expected)
    end
  end

  describe ".call with Tom Cruise movies fixture" do
    let(:expected) do
      JSON.parse(File.read((File.expand_path("fixtures/tom_cruise_movies.json", __dir__))))["artworks"]
    end
    let(:result) { Extractor.call(File.expand_path("fixtures/tom_cruise_movies.html", __dir__)) }

    it "matches Tom Cruise movies reference output" do
      expect(result).to eq(expected)
    end
  end
end

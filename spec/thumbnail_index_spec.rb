require "nokolexbor"

RSpec.describe Extractor::ThumbnailIndex do
  def doc_for(script_body)
    Nokolexbor::HTML("<html><body><script>#{script_body}</script></body></html>")
  end

  it "maps a single id to its data URI" do
    body = "(function(){var s='data:image/jpeg;base64,ABC';" \
           "var ii=['img_1'];var r='';_setImagesSrc(ii,s,r);})();"
    expect(described_class.build(doc_for(body))).to eq("img_1" => "data:image/jpeg;base64,ABC")
  end

  it "can handle different variable names with different script structure" do
    body = "(function(){var ids=['img_1'];var source='data:image/jpeg;base64,ABC';" \
           "_setImagesSrc(ids,source);})();"
    expect(described_class.build(doc_for(body))).to eq("img_1" => "data:image/jpeg;base64,ABC")
  end

  it "maps multiple ids in the same call to the same URI" do
    body = "(function(){var s='data:image/jpeg;base64,XYZ';" \
           "var ii=['a','b','c'];var r='';_setImagesSrc(ii,s,r);})();"
    out = described_class.build(doc_for(body))
    expect(out).to eq("a" => "data:image/jpeg;base64,XYZ",
                      "b" => "data:image/jpeg;base64,XYZ",
                      "c" => "data:image/jpeg;base64,XYZ")
  end

  it "decodes the \\x3d base64 padding escape Google emits" do
    body = "(function(){var s='data:image/jpeg;base64,QUJDRA\\x3d\\x3d';" \
           "var ii=['x'];var r='';_setImagesSrc(ii,s,r);})();"
    expect(described_class.build(doc_for(body))["x"]).to eq("data:image/jpeg;base64,QUJDRA==")
  end

  it "ignores scripts that don't contain _setImagesSrc" do
    expect(described_class.build(doc_for("var unrelated = 1;"))).to eq({})
  end
end

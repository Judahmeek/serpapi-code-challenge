require "nokolexbor"
require "nokogiri"

RSpec.describe do
  html = <<~HTML
    <html><body>
      <div id="weak">
        <div>One</div>
        <div>Two</div>
        <div>Three</div>
      </div>
      <div id="strong">
        <div>One</div>
        <div>Two</div>
        <div>Three</div>
      </div>
      <div id="strong">
        <div>One</div>
        <div>Two</div>
      </div>
    </body></html>
  HTML

  it "Nokogiri tracks node object ID" do
    doc = Nokogiri::HTML(html)

    leaves = doc.css('div > div')
    expect(leaves.size).to be(8)
    parent_groups = leaves.group_by(&:parent)
    expect(parent_groups.size).to be(3)
  end

  it "Nokolexbor does not track node object ID" do
    doc = Nokolexbor::HTML(html)

    leaves = doc.css('div > div')
    expect(leaves.size).to be(8)
    parent_groups = leaves.group_by(&:parent)
    expect(parent_groups.size).to be(3)
  end

  it "Using a combination of hashed serialization and children count seems like a performant compromise" do
    doc = Nokolexbor::HTML(html)

    leaves = doc.css('div > div')
    expect(leaves.size).to be(8)
    parent_groups = leaves.group_by { |root| root.parent.to_s.hash + root.parent.element_children.size }
    expect(parent_groups.size).to be(3)
  end
end

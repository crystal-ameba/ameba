require "spec"
require "../src/ameba"

struct DummyRule < Ameba::Rule
  def test(source)
  end
end

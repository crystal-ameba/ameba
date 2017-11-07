require "spec"
require "../src/ameba"

module Ameba
  struct DummyRule < Rule::Base
    def test(source)
    end
  end

  struct BeValidExpectation
    def match(source)
      source.valid?
    end

    def failure_message(source)
      String.build do |str|
        str << "Source expected to be valid, but there are errors:\n\n"
        source.errors.each do |e|
          str << "  * #{e.rule.name}: #{e.message}\n"
        end
      end
    end

    def negative_failure_message(source)
      "Source expected to be invalid, but it is valid."
    end
  end
end

def be_valid
  Ameba::BeValidExpectation.new
end

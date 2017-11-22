require "spec"
require "../src/ameba"

module Ameba
  struct DummyRule < Rule::Base
    properties do
      description : String = "Dummy rule that does nothing."
    end

    def test(source)
    end
  end

  class DummyFormatter < Formatter::BaseFormatter
    property started_sources : Array(Source)?
    property finished_sources : Array(Source)?
    property started_source : Source?
    property finished_source : Source?

    def started(sources)
      @started_sources = sources
    end

    def source_finished(source : Source)
      @started_source = source
    end

    def source_started(source : Source)
      @finished_source = source
    end

    def finished(sources)
      @finished_sources = sources
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

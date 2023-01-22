module Ameba::Spec
  module BeValid
    def be_valid
      BeValidExpectation.new
    end
  end

  struct BeValidExpectation
    def match(source)
      source.valid?
    end

    def failure_message(source)
      String.build do |str|
        str << "Source expected to be valid, but there are issues: \n\n"
        source.issues.reject(&.disabled?).each do |issue|
          str << "  * #{issue.rule.name}: #{issue.message}\n"
        end
      end
    end

    def negative_failure_message(source)
      "Source expected to be invalid, but it is valid."
    end
  end
end

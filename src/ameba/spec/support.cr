# Require this file to load code that supports testing Ameba rules.

require "./be_valid"
require "./expect_issue"
require "./util"

module Ameba
  class Source
    include Spec::Util

    def initialize(code : String, @path = "", normalize = true)
      @code = normalize ? normalize_code(code) : code
    end
  end
end

include Ameba::Spec::BeValid
include Ameba::Spec::ExpectIssue

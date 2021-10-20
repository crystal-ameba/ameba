# Require this file to load code that supports testing Ameba rules.

require "./spec_support/be_valid"
require "./spec_support/expect_issue"
require "./spec_support/util"

module Ameba
  include Ameba::SpecSupport::Util

  class Source
    def initialize(code : String, @path = "", normalize = true)
      @code = normalize ? normalize_code(code) : code
    end
  end
end

include Ameba::SpecSupport::BeValid
include Ameba::SpecSupport::ExpectIssue

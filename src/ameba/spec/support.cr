# Require this file to load code that supports testing Ameba rules.

require "./be_valid"
require "./expect_issue"
require "./util"

module Ameba
  class Source
    def self.new(code : String, *args, normalize = true, **opts)
      code = normalize ? Spec::Util.normalize_code(code) : code
      new(code, *args, **opts)
    end
  end
end

include Ameba::Spec::BeValid
include Ameba::Spec::ExpectIssue

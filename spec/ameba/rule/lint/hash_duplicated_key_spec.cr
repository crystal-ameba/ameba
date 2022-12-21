require "../../../spec_helper"

module Ameba::Rule::Lint
  describe HashDuplicatedKey do
    subject = HashDuplicatedKey.new

    it "passes if there is no duplicated keys in a hash literals" do
      expect_no_issues subject, <<-CRYSTAL
        h = {"a" => 1, :a => 2, "b" => 3}
        h = {"a" => 1, "b" => 2, "c" => {"a" => 3, "b" => 4}}
        h = {} of String => String
        CRYSTAL
    end

    it "fails if there is a duplicated key in a hash literal" do
      expect_issue subject, <<-CRYSTAL
        h = {"a" => 1, "b" => 2, "a" => 3}
          # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Duplicated keys in hash literal: "a"
        CRYSTAL
    end

    it "fails if there is a duplicated key in the inner hash literal" do
      expect_issue subject, <<-CRYSTAL
        h = {"a" => 1, "b" => {"a" => 3, "b" => 4, "a" => 5}}
                            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Duplicated keys in hash literal: "a"
        CRYSTAL
    end

    it "reports multiple duplicated keys" do
      expect_issue subject, <<-CRYSTAL
        h = {"key1" => 1, "key1" => 2, "key2" => 3, "key2" => 4}
          # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Duplicated keys in hash literal: "key1", "key2"
        CRYSTAL
    end
  end
end

require "../../spec_helper"
require "../../../src/ameba/cli/cmd"

module Ameba::Cli
  describe "Cmd" do
    describe ".run" do
      it "runs ameba" do
        r = Cli.run %w(-f silent file.cr)
        r.should be_nil
      end
    end

    describe ".parse_args" do
      %w(-s --silent).each do |f|
        it "accepts #{f} flag" do
          c = Cli.parse_args [f]
          c.formatter.should eq :silent
        end
      end

      %w(-c --config).each do |f|
        it "accepts #{f} flag" do
          c = Cli.parse_args [f, "config.yml"]
          c.config.should eq "config.yml"
        end
      end

      %w(-f --format).each do |f|
        it "accepts #{f} flag" do
          c = Cli.parse_args [f, "my-formatter"]
          c.formatter.should eq "my-formatter"
        end
      end

      it "accepts --only flag" do
        c = Cli.parse_args ["--only", "RULE1,RULE2"]
        c.only.should eq %w(RULE1 RULE2)
      end

      it "accepts --except flag" do
        c = Cli.parse_args ["--except", "RULE1,RULE2"]
        c.except.should eq %w(RULE1 RULE2)
      end

      it "accepts --gen-config flag" do
        c = Cli.parse_args %w(--gen-config)
        c.formatter.should eq :todo
      end

      it "ignores --config if --gen-config flag passed" do
        c = Cli.parse_args %w(--gen-config --config my_config.yml)
        c.formatter.should eq :todo
        c.config.should eq ""
      end

      it "accepts unknown args as files" do
        c = Cli.parse_args %w(source1.cr source2.cr)
        c.files.should eq %w(source1.cr source2.cr)
      end

      it "allows args to be blank" do
        c = Cli.parse_args [] of String
        c.formatter.should be_nil
        c.files.should be_nil
        c.only.should be_nil
        c.except.should be_nil
        c.config.should eq Config::PATH
      end
    end
  end
end

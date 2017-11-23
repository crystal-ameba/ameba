require "../spec_helper"

module Ameba
  describe Config do
    config_sample = "config/ameba.yml"

    describe ".load" do
      it "loads custom config" do
        config = Config.load config_sample
        config.should_not be_nil
        config.files.should_not be_nil
        config.formatter.should_not be_nil
      end

      it "loads default config" do
        config = Config.load
        config.should_not be_nil
        config.files.should_not be_nil
        config.formatter.should_not be_nil
      end
    end

    describe "#files, #files=" do
      config = Config.load config_sample

      it "holds source files" do
        config.files.should contain "spec/ameba/config_spec.cr"
      end

      it "allows to set files" do
        config.files = ["file.cr"]
        config.files.should eq ["file.cr"]
      end
    end

    describe "#formatter, formatter=" do
      config = Config.load config_sample
      formatter = DummyFormatter.new

      it "contains default formatter" do
        config.formatter.should_not be_nil
      end

      it "allows to set formatter" do
        config.formatter = formatter
        config.formatter.should eq formatter
      end
    end
  end
end

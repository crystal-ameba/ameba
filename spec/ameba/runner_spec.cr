require "../spec_helper"

module Ameba
  private def runner(files = [__FILE__], formatter = DummyFormatter.new)
    config = Config.load "config/ameba.yml"
    config.formatter = formatter
    config.files = files

    Runner.new(config)
  end

  describe Runner do
    formatter = DummyFormatter.new

    describe "#run" do
      it "returns self" do
        runner.run.should_not be_nil
      end

      it "calls started callback" do
        runner(formatter: formatter).run
        formatter.started_sources.should_not be_nil
      end

      it "calls finished callback" do
        runner(formatter: formatter).run
        formatter.finished_sources.should_not be_nil
      end

      it "calls source_started callback" do
        runner(formatter: formatter).run
        formatter.started_source.should_not be_nil
      end

      it "calls source_finished callback" do
        runner(formatter: formatter).run
        formatter.finished_source.should_not be_nil
      end
    end

    describe "#success?" do
      it "returns true if runner has not been run" do
        runner.success?.should be_true
      end

      it "returns true if all sources are valid" do
        runner.run.success?.should be_true
      end

      it "returns false if there are invalid sources" do
        s = Source.new %q(
          WrongConstant = 5
        )
        Runner.new([s], formatter).run.success?.should be_false
      end
    end
  end
end

require "../../spec_helper"

private def rescue_node(code)
  handler = Crystal::Parser.new(code).parse.as(Crystal::ExceptionHandler)
  rescues = handler.rescues.should_not be_nil
  rescues.first
end

describe Crystal::Rescue do
  describe "#end_location" do
    {
      "rescue ex : Exception" => 21,
      "rescue ex"             => 9,
      "rescue Exception"      => 16,
      "rescue"                => 6,
    }.each do |header, column_number|
      it "returns the end location of the `#{header}` header" do
        node = rescue_node <<-CRYSTAL
          begin
          #{header}
            puts :rescued
          end
          CRYSTAL

        end_location = node.end_location.should_not be_nil
        end_location.line_number.should eq 2
        end_location.column_number.should eq column_number
      end
    end
  end
end

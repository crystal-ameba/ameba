require "../../spec_helper"
require "../../../src/ameba/cli/cmd"

module Ameba::CLI
  root = Path[__DIR__, "..", "..", ".."].expand

  describe "Cmd" do
    describe ".run" do
      it "runs ameba" do
        r = CLI.run %w[-f silent file.cr]
        r.should be_true
      end
    end

    describe ".parse_args" do
      %w[-s --silent].each do |flag|
        it "accepts #{flag} flag" do
          c = CLI.parse_args [flag]
          c.formatter.should eq :silent
        end
      end

      %w[-c --config].each do |flag|
        it "accepts #{flag} flag" do
          c = CLI.parse_args [flag, "config.yml"]
          c.config.should eq Path["config.yml"]
        end
      end

      %w[-f --format].each do |flag|
        it "accepts #{flag} flag" do
          c = CLI.parse_args [flag, "my-formatter"]
          c.formatter.should eq "my-formatter"
        end
      end

      %w[-u --up-to-version].each do |flag|
        it "accepts #{flag} flag" do
          c = CLI.parse_args [flag, "1.5.0"]
          c.version.should eq "1.5.0"
        end
      end

      it "accepts --stdin-filename flag" do
        c = CLI.parse_args %w[--stdin-filename foo.cr]
        c.stdin_filename.should eq "foo.cr"
      end

      it "accepts --only flag" do
        c = CLI.parse_args ["--only", "RULE1,RULE2"]
        c.only.should eq Set{"RULE1", "RULE2"}
      end

      it "accepts --except flag" do
        c = CLI.parse_args ["--except", "RULE1,RULE2"]
        c.except.should eq Set{"RULE1", "RULE2"}
      end

      it "defaults rules? flag to false" do
        c = CLI.parse_args %w[file.cr]
        c.rules?.should be_false
      end

      it "defaults skip_reading_config? flag to false" do
        c = CLI.parse_args %w[file.cr]
        c.skip_reading_config?.should be_false
      end

      it "accepts --rules flag" do
        c = CLI.parse_args %w[--rules]
        c.rules?.should be_true
      end

      it "defaults all? flag to false" do
        c = CLI.parse_args %w[file.cr]
        c.all?.should be_false
      end

      it "accepts --all flag" do
        c = CLI.parse_args %w[--all]
        c.all?.should be_true
      end

      it "accepts --gen-config flag" do
        c = CLI.parse_args %w[--gen-config]
        c.formatter.should eq :todo
      end

      it "accepts --no-color flag" do
        c = CLI.parse_args %w[--no-color]
        c.colors?.should be_false
      end

      it "accepts --without-affected-code flag" do
        c = CLI.parse_args %w[--without-affected-code]
        c.without_affected_code?.should be_true
      end

      it "doesn't disable colors by default" do
        c = CLI.parse_args %w[--all]
        c.colors?.should be_true
      end

      it "ignores --config if --gen-config flag passed" do
        c = CLI.parse_args %w[--gen-config --config my_config.yml]
        c.formatter.should eq :todo
        c.skip_reading_config?.should be_true
      end

      describe "-e/--explain" do
        it "configures file/line/column" do
          c = CLI.parse_args %w[--explain src/file.cr:3:5]

          location_to_explain = c.location_to_explain.should_not be_nil
          location_to_explain[:file].should eq "src/file.cr"
          location_to_explain[:line].should eq 3
          location_to_explain[:column].should eq 5
        end

        it "raises an error if location is not valid" do
          expect_raises(Exception, "location should have PATH:line:column") do
            CLI.parse_args %w[--explain src/file.cr:3]
          end
        end

        it "raises an error if line number is not valid" do
          expect_raises(Exception, "location should have PATH:line:column") do
            CLI.parse_args %w[--explain src/file.cr:a:3]
          end
        end

        it "raises an error if column number is not valid" do
          expect_raises(Exception, "location should have PATH:line:column") do
            CLI.parse_args %w[--explain src/file.cr:3:&]
          end
        end

        it "raises an error if line/column are missing" do
          expect_raises(Exception, "location should have PATH:line:column") do
            CLI.parse_args %w[--explain src/file.cr]
          end
        end
      end

      context "--fail-level" do
        it "configures fail level Convention" do
          c = CLI.parse_args %w[--fail-level convention]
          c.fail_level.should eq Severity::Convention
        end

        it "configures fail level Warning" do
          c = CLI.parse_args %w[--fail-level Warning]
          c.fail_level.should eq Severity::Warning
        end

        it "configures fail level Error" do
          c = CLI.parse_args %w[--fail-level error]
          c.fail_level.should eq Severity::Error
        end

        it "raises if fail level is incorrect" do
          expect_raises(Exception, "Incorrect severity name JohnDoe") do
            CLI.parse_args %w[--fail-level JohnDoe]
          end
        end
      end

      it "accepts unknown args as globs" do
        c = CLI.parse_args %w[source1.cr source2.cr]
        c.globs.should eq Set{
          Path["source1.cr"].expand.to_posix.to_s,
          Path["source2.cr"].expand.to_posix.to_s,
        }
      end

      it "leaves the absolute paths intact" do
        c = CLI.parse_args [
          Path[Dir.tempdir, "foo.cr"].to_s,
          Path[Dir.tempdir, "bar.cr"].to_s,
          Path[Dir.tempdir, "baz*.cr"].to_s,
        ]
        c.root.should eq Path[Dir.current]
        c.globs.should eq Set{
          Path[Dir.tempdir, "foo.cr"].to_posix.to_s,
          Path[Dir.tempdir, "bar.cr"].to_posix.to_s,
          Path[Dir.tempdir, "baz*.cr"].to_posix.to_s,
        }
      end

      it "expands relative globs using current directory as base" do
        c = CLI.parse_args [Path[Dir.tempdir, "foo.cr"].to_s, "**/bar.cr"]
        c.root.should eq Path[Dir.current]
        c.globs.should eq Set{
          Path[Dir.tempdir, "/foo.cr"].to_posix.to_s,
          Path[Dir.current, "/**/bar.cr"].to_posix.to_s,
        }
      end

      it "expands relative globs using project root directory as base" do
        c = CLI.parse_args [root.to_s, Path[Dir.tempdir, "foo.cr"].to_s, "**/bar.cr"]
        c.root.should eq root
        c.globs.should eq Set{
          root.to_posix.to_s,
          Path[Dir.tempdir, "/foo.cr"].to_posix.to_s,
          Path[Dir.current, "/**/bar.cr"].to_posix.to_s,
        }
      end

      it "accepts single '-' argument as STDIN" do
        c = CLI.parse_args %w[-]
        c.stdin_filename.should eq "-"
      end

      it "accepts one unknown arg as explain location if it has correct format" do
        c = CLI.parse_args %w[source.cr:3:22]

        location_to_explain = c.location_to_explain.should_not be_nil
        location_to_explain[:file].should eq "source.cr"
        location_to_explain[:line].should eq 3
        location_to_explain[:column].should eq 22
      end

      it "allows args to be blank" do
        c = CLI.parse_args [] of String
        c.formatter.should be_nil
        c.globs.should be_nil
        c.only.should be_nil
        c.except.should be_nil
        c.config.should be_nil
      end
    end
  end
end

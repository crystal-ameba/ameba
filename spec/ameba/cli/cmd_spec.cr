require "../../spec_helper"
require "../../../src/ameba/cli/cmd"

module Ameba::CLI
  root = Path[__DIR__, "..", "..", "fixtures"].expand

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
          opts = CLI.parse_args [flag]
          opts.formatter.should eq :silent
        end
      end

      %w[-c --config].each do |flag|
        it "accepts #{flag} flag" do
          opts = CLI.parse_args [flag, "config.yml"]
          opts.config.should eq Path["config.yml"]
        end
      end

      %w[-f --format].each do |flag|
        it "accepts #{flag} flag" do
          opts = CLI.parse_args [flag, "my-formatter"]
          opts.formatter.should eq "my-formatter"
        end
      end

      %w[-u --up-to-version].each do |flag|
        it "accepts #{flag} flag" do
          opts = CLI.parse_args [flag, "1.5.0"]
          opts.version.should eq "1.5.0"
        end
      end

      it "accepts --stdin-filename flag" do
        opts = CLI.parse_args %w[--stdin-filename foo.cr]
        opts.stdin_filename.should eq "foo.cr"
      end

      it "accepts --only flag" do
        opts = CLI.parse_args ["--only", "RULE1,RULE2"]
        opts.only.should eq Set{"RULE1", "RULE2"}
      end

      it "accepts --except flag" do
        opts = CLI.parse_args ["--except", "RULE1,RULE2"]
        opts.except.should eq Set{"RULE1", "RULE2"}
      end

      it "defaults rules? flag to false" do
        opts = CLI.parse_args %w[file.cr]
        opts.rules?.should be_false
      end

      it "defaults skip_reading_config? flag to false" do
        opts = CLI.parse_args %w[file.cr]
        opts.skip_reading_config?.should be_false
      end

      it "accepts --rules flag" do
        opts = CLI.parse_args %w[--rules]
        opts.rules?.should be_true
      end

      it "defaults all? flag to false" do
        opts = CLI.parse_args %w[file.cr]
        opts.all?.should be_false
      end

      it "accepts --all flag" do
        opts = CLI.parse_args %w[--all]
        opts.all?.should be_true
      end

      it "accepts --gen-config flag" do
        opts = CLI.parse_args %w[--gen-config]
        opts.formatter.should eq :todo
      end

      it "accepts --no-color flag" do
        opts = CLI.parse_args %w[--no-color]
        opts.colors?.should be_false
      end

      it "accepts --without-affected-code flag" do
        opts = CLI.parse_args %w[--without-affected-code]
        opts.without_affected_code?.should be_true
      end

      it "doesn't disable colors by default" do
        opts = CLI.parse_args %w[--all]
        opts.colors?.should be_true
      end

      it "ignores --config if --gen-config flag passed" do
        opts = CLI.parse_args %w[--gen-config --config my_config.yml]
        opts.formatter.should eq :todo
        opts.skip_reading_config?.should be_true
      end

      describe "-e/--explain" do
        it "configures file/line/column" do
          opts = CLI.parse_args %w[--explain src/file.cr:3:5]

          location_to_explain = opts.location_to_explain.should_not be_nil
          location_to_explain.filename.should eq "src/file.cr"
          location_to_explain.line_number.should eq 3
          location_to_explain.column_number.should eq 5
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

      context "--min-severity" do
        it "configures fail level Convention" do
          opts = CLI.parse_args %w[--min-severity convention]
          opts.severity.should eq Severity::Convention
        end

        it "configures fail level Warning" do
          opts = CLI.parse_args %w[--min-severity Warning]
          opts.severity.should eq Severity::Warning
        end

        it "configures fail level Error" do
          opts = CLI.parse_args %w[--min-severity error]
          opts.severity.should eq Severity::Error
        end

        it "raises if fail level is incorrect" do
          expect_raises(Exception, "Incorrect severity name JohnDoe") do
            CLI.parse_args %w[--min-severity JohnDoe]
          end
        end
      end

      it "sets #root to the first directory passed as an argument if it's a project directory" do
        opts = CLI.parse_args [root.to_s]
        opts.root.should eq root
      end

      it "sets #root to the current directory if the given directory is not a project directory" do
        opts = CLI.parse_args [Dir.tempdir]
        opts.root.should eq Path[Dir.current]
      end

      it "sets #root to the current directory if no project directory is passed" do
        opts = CLI.parse_args %w[]
        opts.root.should eq Path[Dir.current]
      end

      it "accepts unknown args as globs" do
        opts = CLI.parse_args %w[source1.cr source2.cr]
        opts.globs.should eq Set{
          Path["source1.cr"].expand.to_posix.to_s,
          Path["source2.cr"].expand.to_posix.to_s,
        }
      end

      it "leaves the absolute paths intact" do
        opts = CLI.parse_args [
          Path[Dir.tempdir, "foo.cr"].to_s,
          Path[Dir.tempdir, "bar.cr"].to_s,
          Path[Dir.tempdir, "baz*.cr"].to_s,
        ]
        opts.root.should eq Path[Dir.current]
        opts.globs.should eq Set{
          Path[Dir.tempdir, "foo.cr"].to_posix.to_s,
          Path[Dir.tempdir, "bar.cr"].to_posix.to_s,
          Path[Dir.tempdir, "baz*.cr"].to_posix.to_s,
        }
      end

      it "expands relative globs using current directory as base" do
        opts = CLI.parse_args [
          Path[Dir.tempdir, "foo.cr"].to_s,
          "**/bar.cr",
        ]
        opts.root.should eq Path[Dir.current]
        opts.globs.should eq Set{
          Path[Dir.tempdir, "foo.cr"].to_posix.to_s,
          Path[Dir.current, "**", "bar.cr"].to_posix.to_s,
        }
      end

      it "expands relative globs using project root directory as base" do
        opts = CLI.parse_args [
          root.to_s,
          Path[Dir.tempdir, "foo.cr"].to_s,
          "**/bar.cr",
        ]
        opts.globs.should eq Set{
          root.to_posix.to_s,
          Path[Dir.tempdir, "foo.cr"].to_posix.to_s,
          Path[Dir.current, "**", "bar.cr"].to_posix.to_s,
        }
      end

      it "accepts single '-' argument as STDIN" do
        opts = CLI.parse_args %w[-]
        opts.stdin_filename.should eq "-"
      end

      it "accepts one unknown arg as explain location if it has correct format" do
        opts = CLI.parse_args %w[source.cr:3:22]

        location_to_explain = opts.location_to_explain.should_not be_nil
        location_to_explain.filename.should eq "source.cr"
        location_to_explain.line_number.should eq 3
        location_to_explain.column_number.should eq 22
      end

      it "allows args to be blank" do
        opts = CLI.parse_args [] of String
        opts.root.should eq Path[Dir.current]
        opts.formatter.should be_nil
        opts.globs.should be_nil
        opts.only.should be_nil
        opts.except.should be_nil
        opts.config.should be_nil
      end
    end
  end
end

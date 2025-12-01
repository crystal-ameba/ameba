require "../spec_helper"

module Ameba
  subject = GlobUtils
  root = Path[__DIR__, "..", ".."]
  current_file_basename = File.basename(__FILE__)
  current_file_path = __FILE__
  current_file_relative_path =
    Path[current_file_path].relative_to(Dir.current).to_s

  describe GlobUtils do
    describe "#find_files_by_globs" do
      it "returns files by directory" do
        subject.find_files_by_globs([__DIR__], root: root)
          .should contain current_file_relative_path
      end

      it "returns a file by filepath" do
        subject.find_files_by_globs([__FILE__], root: root)
          .should eq [current_file_relative_path]
      end

      it "returns a file by globs" do
        subject.find_files_by_globs(["**/#{current_file_basename}"], root: root)
          .should eq [current_file_relative_path]
      end

      it "returns files by globs" do
        subject.find_files_by_globs(["**/*_spec.cr"], root: root)
          .should contain current_file_relative_path
      end

      it "doesn't return rejected globs" do
        subject
          .find_files_by_globs(["**/*_spec.cr", "!**/#{current_file_basename}"], root: root)
          .should_not contain current_file_relative_path
      end

      it "doesn't return rejected folders" do
        subject
          .find_files_by_globs(["**/*_spec.cr", "!spec"], root: root)
          .should be_empty
      end

      it "doesn't return duplicated globs" do
        subject
          .find_files_by_globs(["**/*_spec.cr", "**/*_spec.cr"], root: root)
          .count(current_file_relative_path)
          .should eq 1
      end
    end

    describe "#expand" do
      it "expands globs" do
        subject.expand(["**/#{current_file_basename}"], root: root)
          .should eq [current_file_relative_path]
      end

      it "does not list duplicated files" do
        subject.expand(["**/#{current_file_basename}", "**/#{current_file_basename}"], root: root)
          .should eq [current_file_relative_path]
      end

      it "does not list folders" do
        subject.expand(["**/*"], root: root).each do |path|
          fail "#{path.inspect} should be a file" unless File.file?(path)
        end
      end

      it "expands folders" do
        subject.expand(["spec"], root: root).should_not be_empty
      end
    end
  end
end

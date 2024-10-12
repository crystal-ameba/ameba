module Ameba::Rule::Lint
  # A rule that reports typos found in source files.
  #
  # NOTE: Needs [typos](https://github.com/crate-ci/typos) CLI tool.
  # NOTE: See the chapter on [false positives](https://github.com/crate-ci/typos#false-positives).
  #
  # YAML configuration example:
  #
  # ```
  # Lint/Typos:
  #   Enabled: true
  #   BinPath: ~
  #   FailOnError: false
  # ```
  class Typos < Base
    properties do
      description "Reports typos found in source files"

      bin_path nil, as: String?
      fail_on_error false
    end

    MSG = "Typo found: %s -> %s"

    BIN_PATH = Process.find_executable("typos") rescue nil

    @@mutex = Mutex.new

    protected record Typo,
      typo : String,
      corrections : Array(String),
      location : {Int32, Int32},
      end_location : {Int32, Int32} do
      def self.parse(str) : self?
        issue = JSON.parse(str)

        return unless issue["type"] == "typo"

        typo = issue["typo"].as_s
        corrections = issue["corrections"].as_a.map(&.as_s)

        return if typo.empty? || corrections.empty?

        line_no = issue["line_num"].as_i
        col_no = issue["byte_offset"].as_i + 1
        end_col_no = col_no + typo.size - 1

        new(typo, corrections,
          {line_no, col_no},
          {line_no, end_col_no})
      end
    end

    protected def self.typos_from(bin_path : String, source : Source) : Array(Typo)?
      result = @@mutex.synchronize do
        status = Process.run(bin_path, args: %w[--format json -],
          input: IO::Memory.new(source.code),
          output: output = IO::Memory.new,
        )
        output.to_s.presence unless status.success?
      end
      return unless result

      ([] of Typo).tap do |typos|
        # NOTE: `--format json` is actually JSON Lines (`jsonl`)
        result.each_line do |line|
          Typo.parse(line).try { |typo| typos << typo }
        end
      end
    end

    def bin_path : String?
      @bin_path || BIN_PATH
    end

    def test(source : Source)
      typos = typos_from(source)
      typos.try &.each do |typo|
        corrections = typo.corrections
        message = MSG % {
          typo.typo, corrections.join(" | "),
        }
        if corrections.size == 1
          issue_for typo.location, typo.end_location, message do |corrector|
            corrector.replace(typo.location, typo.end_location, corrections.first)
          end
        else
          issue_for typo.location, typo.end_location, message
        end
      end
    rescue ex
      raise ex if fail_on_error?
    end

    protected def typos_from(source : Source) : Array(Typo)?
      if bin_path = self.bin_path
        return Typos.typos_from(bin_path, source)
      end
      if fail_on_error?
        raise RuntimeError.new "Could not find `typos` executable"
      end
    end
  end
end

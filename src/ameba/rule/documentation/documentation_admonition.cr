module Ameba::Rule::Documentation
  # A rule that reports documentation admonitions.
  #
  # Optionally, these can fail at an appropriate time.
  #
  # ```
  # def get_user(id)
  #   # TODO(2024-04-24) Fix this hack when the database migration is complete
  #   if id < 1_000_000
  #     v1_api_call(id)
  #   else
  #     v2_api_call(id)
  #   end
  # end
  # ```
  #
  # `TODO` comments are used to remind yourself of source code related things.
  #
  # The premise here is that `TODO` should be dealt with in the near future
  # and are therefore reported by Ameba.
  #
  # `FIXME` comments are used to indicate places where source code needs fixing.
  #
  # The premise here is that `FIXME` should indeed be fixed as soon as possible
  # and are therefore reported by Ameba.
  #
  # YAML configuration example:
  #
  # ```
  # Documentation/DocumentationAdmonition:
  #   Enabled: true
  #   Admonitions: [TODO, FIXME, BUG]
  #   Timezone: UTC
  # ```
  class DocumentationAdmonition < Base
    properties do
      description "Reports documentation admonitions"
      admonitions %w[TODO FIXME BUG]
      timezone "UTC"
    end

    MSG      = "Found a %s admonition in a comment"
    MSG_LATE = "Found a %s admonition in a comment (%s)"
    MSG_ERR  = "%s admonition error: %s"

    @[YAML::Field(ignore: true)]
    private getter location : Time::Location {
      Time::Location.load(self.timezone)
    }

    def test(source)
      Tokenizer.new(source).run do |token|
        next unless token.type.comment?
        next unless doc = token.value.to_s

        pattern =
          /^#\s*(?<admonition>#{Regex.union(admonitions)})(?:\((?<context>.+?)\))?(?:\W+|$)/m

        matches = doc.scan(pattern)
        matches.each do |match|
          admonition = match["admonition"]
          begin
            case expr = match["context"]?.presence
            when /\A\d{4}-\d{2}-\d{2}\Z/ # date
              # ameba:disable Lint/NotNil
              date = Time.parse(expr.not_nil!, "%F", location)
              issue_for_date source, token, admonition, date
            when /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?\Z/ # date + time (no tz)
              # ameba:disable Lint/NotNil
              date = Time.parse(expr.not_nil!, "%F #{$1?.presence ? "%T" : "%R"}", location)
              issue_for_date source, token, admonition, date
            else
              issue_for token, MSG % admonition
            end
          rescue ex
            issue_for token, MSG_ERR % {admonition, "#{ex}: #{expr.inspect}"}
          end
        end
      end
    end

    private def issue_for_date(source, node, admonition, date)
      diff = Time.utc - date.to_utc

      return if diff.negative?

      past = case diff
             when 0.seconds..1.day then "today is the day!"
             when 1.day..2.days    then "1 day past"
             else                       "#{diff.total_days.to_i} days past"
             end

      issue_for node, MSG_LATE % {admonition, past}
    end
  end
end

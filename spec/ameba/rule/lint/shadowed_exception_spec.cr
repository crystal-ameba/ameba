require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ShadowedException do
    subject = ShadowedException.new

    it "passes if there isn't shadowed exception" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          do_something
        rescue ArgumentError
          handle_argument_error_exception
        rescue Exception
          handle_exception
        end

        def method
        rescue Exception
          handle_exception
        end

        def method
        rescue e : ArgumentError
          handle_argument_error_exception
        rescue e : Exception
          handle_exception
        end
      CRYSTAL
    end

    it "fails if there is a shadowed exception" do
      expect_issue subject, <<-CRYSTAL
        begin
          do_something
        rescue Exception
          handle_exception
        rescue ArgumentError
             # ^^^^^^^^^^^^^ error: Shadowed exception found: ArgumentError
          handle_argument_error_exception
        end
      CRYSTAL
    end

    it "fails if there is a custom shadowed exceptions" do
      expect_issue subject, <<-CRYSTAL
        begin
          1
        rescue Exception
          2
        rescue MySuperException
             # ^^^^^^^^^^^^^^^^ error: Shadowed exception found: MySuperException
          3
        end
      CRYSTAL
    end

    it "fails if there is a shadowed exception in a type list" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue Exception | IndexError
                         # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        end
      CRYSTAL
    end

    it "fails if there is a first shadowed exception in a type list" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue IndexError | Exception
             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        rescue Exception
             # ^^^^^^^^^ error: Shadowed exception found: Exception
        rescue
        end
      CRYSTAL
    end

    it "fails if there is a shadowed duplicated exception" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue IndexError
        rescue ArgumentError
        rescue IndexError
             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        end
      CRYSTAL
    end

    it "fails if there is a shadowed duplicated exception in a type list" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue IndexError
        rescue ArgumentError | IndexError
                             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        end
      CRYSTAL
    end

    it "fails if there is only shadowed duplicated exceptions" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue IndexError
        rescue IndexError
             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        rescue Exception
        end
      CRYSTAL
    end

    it "fails if there is only shadowed duplicated exceptions in a type list" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue IndexError | IndexError
                          # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        end
      CRYSTAL
    end

    it "fails if all rescues are shadowed and there is a catch-all rescue" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue Exception
        rescue ArgumentError
             # ^^^^^^^^^^^^^ error: Shadowed exception found: ArgumentError
        rescue IndexError
             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        rescue KeyError | IO::Error
                        # ^^^^^^^^^ error: Shadowed exception found: IO::Error
             # ^^^^^^^^ error: Shadowed exception found: KeyError
        rescue
        end
      CRYSTAL
    end

    it "fails if there are shadowed exception with args" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue Exception
        rescue ex : IndexError
                  # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        rescue
        end
      CRYSTAL
    end

    it "fails if there are multiple shadowed exceptions" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue Exception
        rescue ArgumentError
             # ^^^^^^^^^^^^^ error: Shadowed exception found: ArgumentError
        rescue IndexError
             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        end
      CRYSTAL
    end

    it "fails if there are multiple shadowed exceptions in a type list" do
      expect_issue subject, <<-CRYSTAL
        begin
        rescue Exception
        rescue ArgumentError | IndexError
                             # ^^^^^^^^^^ error: Shadowed exception found: IndexError
             # ^^^^^^^^^^^^^ error: Shadowed exception found: ArgumentError
        rescue IO::Error
             # ^^^^^^^^^ error: Shadowed exception found: IO::Error
        end
        CRYSTAL
    end

    it "fails if there are multiple shadowed exceptions in a single rescue" do
      expect_issue subject, <<-CRYSTAL
        begin
          do_something
        rescue Exception | IndexError | ArgumentError
                                      # ^^^^^^^^^^^^^ error: Shadowed exception found: ArgumentError
                         # ^^^^^^^^^^ error: Shadowed exception found: IndexError
        end
        CRYSTAL
    end
  end
end

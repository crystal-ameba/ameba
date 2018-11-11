require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnreachableCode.new

  describe UnreachableCode do
    context "return" do
      it "reports if there is unreachable code after return" do
        s = Source.new %(
          def foo
            a = 1
            return false
            b = 2
          end
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":4:3"
      end

      it "doesn't report if there is return in if" do
        s = Source.new %(
          def foo
            a = 1
            return false if bar
            b = 2
          end
        )
        subject.catch(s).should be_valid
      end

      it "doesn't report if there are returns in if-then-else" do
        s = Source.new %(
          if a > 0
            return :positive
          else
            return :negative
          end
        )
        subject.catch(s).should be_valid
      end

      it "doesn't report if return is used in a block" do
        s = Source.new %(
          def foo
            bar = obj.try do
              if something
                a = 1
              end
              return nil
            end

            bar
          end
        )
        subject.catch(s).should be_valid
      end

      pending "reports if there is unreachable code after if-then-else" do
        s = Source.new %(
          def foo
            if a > 0
              return :positive
            else
              return :negative
            end

            :unreachable
          end
        )
        subject.catch(s).should_not be_valid
        issue = s.issues.first
        issue.location.to_s.should eq ":8:4"
      end
    end

    context "break" do
      it "reports if there is unreachable code after break" do
        s = Source.new %(
          def foo
            loop do
              break
              a = 1
            end
          end
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":4:5"
      end

      it "doesn't report if break is in a condition" do
        s = Source.new %(
          a = -100
          while true
            break if a > 0
            a += 1
          end
        )
        subject.catch(s).should be_valid
      end
    end

    context "next" do
      it "reports if there is unreachable code after next" do
        s = Source.new %(
          a = 1
          while a < 5
            next
            puts a
          end
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":4:3"
      end

      it "doesn't report if next is in a condition" do
        s = Source.new %(
          a = 1
          while a < 5
            if a == 3
              next
            end
            puts a
          end
        )
        subject.catch(s).should be_valid
      end
    end

    context "raise" do
      it "reports if there is unreachable code after raise" do
        s = Source.new %(
          a = 1
          raise "exception"
          b = 2
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":3:1"
      end

      it "doesn't report if raise is in a condition" do
        s = Source.new %(
          a = 1
          raise "exception" if a > 0
          b = 2
        )
        subject.catch(s).should be_valid
      end
    end

    context "exit" do
      it "reports if there is unreachable code after exit without args" do
        s = Source.new %(
          a = 1
          exit
          b = 2
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":3:1"
      end

      it "reports if there is unreachable code after exit with exit code" do
        s = Source.new %(
          a = 1
          exit 1
          b = 2
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":3:1"
      end

      it "doesn't report if exit is in a condition" do
        s = Source.new %(
          a = 1
          exit if a > 0
          b = 2
        )
        subject.catch(s).should be_valid
      end
    end

    context "abort" do
      it "reports if there is unreachable code after abort with one argument" do
        s = Source.new %(
          a = 1
          abort "abort"
          b = 2
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":3:1"
      end

      it "reports if there is unreachable code after abort with two args" do
        s = Source.new %(
          a = 1
          abort "abort", 1
          b = 2
        )
        subject.catch(s).should_not be_valid

        issue = s.issues.first
        issue.location.to_s.should eq ":3:1"
      end

      it "doesn't report if abort is in a condition" do
        s = Source.new %(
          a = 1
          abort "abort" if a > 0
          b = 2
        )
        subject.catch(s).should be_valid
      end
    end
  end
end

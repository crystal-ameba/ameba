require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SharedVarInFiber do
    subject = SharedVarInFiber.new

    it "doesn't report if there is only local shared var in fiber" do
      expect_no_issues subject, %(
        spawn do
          i = 1
          puts i
        end

        Fiber.yield
      )
    end

    it "doesn't report if there is only block shared var in fiber" do
      expect_no_issues subject, %(
        10.times do |i|
          spawn do
            puts i
          end
        end

        Fiber.yield
      )
    end

    it "doesn't report if there a spawn macro is used" do
      expect_no_issues subject, %(
        i = 0
        while i < 10
          spawn puts(i)
          i += 1
        end

        Fiber.yield
      )
    end

    it "reports if there is a shared var in spawn" do
      expect_issue subject, %(
        i = 0
        while i < 10
          spawn do
            puts(i)
               # ^ error: Shared variable `i` is used in fiber
          end
          i += 1
        end

        Fiber.yield
      )
    end

    it "reports reassigned reference to shared var in spawn" do
      expect_issue subject, %(
        channel = Channel(String).new
        n = 0

        while n < 10
          n = n + 1
          spawn do
            m = n
              # ^ error: Shared variable `n` is used in fiber
            channel.send m
          end
        end
      )
    end

    it "doesn't report reassigned reference to shared var in block" do
      expect_no_issues subject, %(
        channel = Channel(String).new
        n = 0

        while n < 3
          n = n + 1
          m = n
          spawn do
            channel.send m
          end
        end
      )
    end

    it "does not report block is called in a spawn" do
      expect_no_issues subject, %(
        def method(block)
          spawn do
            block.call(10)
          end
        end
      )
    end

    it "reports multiple shared variables in spawn" do
      expect_issue subject, %(
        foo, bar, baz = 0, 0, 0
        while foo < 10
          baz += 1
          spawn do
            puts foo
               # ^^^ error: Shared variable `foo` is used in fiber
            puts foo + bar + baz
               # ^^^ error: Shared variable `foo` is used in fiber
                           # ^^^ error: Shared variable `baz` is used in fiber
          end
          foo += 1
        end
      )
    end

    it "doesn't report if variable is passed to the proc" do
      expect_no_issues subject, %(
        i = 0
        while i < 10
          proc = ->(x : Int32) do
            spawn do
            puts(x)
            end
          end
          proc.call(i)
          i += 1
        end
      )
    end

    it "doesn't report if a channel is declared in outer scope" do
      expect_no_issues subject, %(
        channel = Channel(Nil).new
        spawn { channel.send(nil) }
        channel.receive
      )
    end

    it "doesn't report if there is a loop in spawn" do
      expect_no_issues subject, %(
        channel = Channel(String).new

        spawn do
          server = TCPServer.new("0.0.0.0", 8080)
          socket = server.accept
          while line = socket.gets
            channel.send(line)
          end
        end
      )
    end

    it "doesn't report if a var is mutated in spawn and referenced outside" do
      expect_no_issues subject, %(
        def method
          foo = 1
          spawn { foo = 2 }
          foo
        end
      )
    end

    it "doesn't report if variable is changed without iterations" do
      expect_no_issues subject, %(
        def foo
          i = 0
          i += 1
          spawn { i }
        end
      )
    end

    it "doesn't report if variable is in a loop inside spawn" do
      expect_no_issues subject, %(
        i = 0
        spawn do
          while i < 10
            i += 1
          end
        end
      )
    end

    it "doesn't report if variable declared inside loop" do
      expect_no_issues subject, %(
        while true
          i = 0
          spawn { i += 1 }
        end
      )
    end

    it "reports rule, location and message" do
      s = Source.new %(
        i = 0
        while true
          i += 1
          spawn { i }
        end
      ), "source.cr"

      subject.catch(s).should_not be_valid
      s.issues.size.should eq 1

      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:4:11"
      issue.end_location.to_s.should eq "source.cr:4:11"
      issue.message.should eq "Shared variable `i` is used in fiber"
    end
  end
end

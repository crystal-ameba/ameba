require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SharedVarInFiber do
    subject = SharedVarInFiber.new

    it "doesn't report if there is only local shared var in fiber" do
      expect_no_issues subject, <<-CRYSTAL
        spawn do
          i = 1
          puts i
        end

        Fiber.yield
        CRYSTAL
    end

    it "doesn't report if there is only block shared var in fiber" do
      expect_no_issues subject, <<-CRYSTAL
        10.times do |i|
          spawn do
            puts i
          end
        end

        Fiber.yield
        CRYSTAL
    end

    it "doesn't report if there a spawn macro is used" do
      expect_no_issues subject, <<-CRYSTAL
        i = 0
        while i < 10
          spawn puts(i)
          i += 1
        end

        Fiber.yield
        CRYSTAL
    end

    it "reports if there is a shared var in spawn (while)" do
      source = expect_issue subject, <<-CRYSTAL
        i = 0
        while i < 10
          spawn do
            puts(i)
               # ^ error: Shared variable `i` is used in fiber
          end
          i += 1
        end

        Fiber.yield
        CRYSTAL

      expect_no_corrections source
    end

    it "reports if there is a shared var in spawn (loop)" do
      source = expect_issue subject, <<-CRYSTAL
        i = 0
        loop do
          break if i >= 10
          spawn do
            puts(i)
               # ^ error: Shared variable `i` is used in fiber
          end
          i += 1
        end

        Fiber.yield
        CRYSTAL

      expect_no_corrections source
    end

    it "reports reassigned reference to shared var in spawn" do
      source = expect_issue subject, <<-CRYSTAL
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
        CRYSTAL

      expect_no_corrections source
    end

    it "doesn't report reassigned reference to shared var in block" do
      expect_no_issues subject, <<-CRYSTAL
        channel = Channel(String).new
        n = 0

        while n < 3
          n = n + 1
          m = n
          spawn do
            channel.send m
          end
        end
        CRYSTAL
    end

    it "does not report block is called in a spawn" do
      expect_no_issues subject, <<-CRYSTAL
        def method(block)
          spawn do
            block.call(10)
          end
        end
        CRYSTAL
    end

    it "reports multiple shared variables in spawn" do
      source = expect_issue subject, <<-CRYSTAL
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
        CRYSTAL

      expect_no_corrections source
    end

    it "doesn't report if variable is passed to the proc" do
      expect_no_issues subject, <<-CRYSTAL
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
        CRYSTAL
    end

    it "doesn't report if a channel is declared in outer scope" do
      expect_no_issues subject, <<-CRYSTAL
        channel = Channel(Nil).new
        spawn { channel.send(nil) }
        channel.receive
        CRYSTAL
    end

    it "doesn't report if there is a loop in spawn" do
      expect_no_issues subject, <<-CRYSTAL
        channel = Channel(String).new

        spawn do
          server = TCPServer.new("0.0.0.0", 8080)
          socket = server.accept
          while line = socket.gets
            channel.send(line)
          end
        end
        CRYSTAL
    end

    it "doesn't report if a var is mutated in spawn and referenced outside" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          foo = 1
          spawn { foo = 2 }
          foo
        end
        CRYSTAL
    end

    it "doesn't report if variable is changed without iterations" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          i = 0
          i += 1
          spawn { i }
        end
        CRYSTAL
    end

    it "doesn't report if variable is in a loop inside spawn" do
      expect_no_issues subject, <<-CRYSTAL
        i = 0
        spawn do
          while i < 10
            i += 1
          end
        end
        CRYSTAL
    end

    it "doesn't report if variable declared inside loop" do
      expect_no_issues subject, <<-CRYSTAL
        while true
          i = 0
          spawn { i += 1 }
        end
        CRYSTAL
    end
  end
end

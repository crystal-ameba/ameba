require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedGenericOrUnion do
    subject = UnusedGenericOrUnion.new

    it "passes if generics and unions are used for assign and method calls" do
      expect_no_issues subject, <<-CRYSTAL
        my_var : String? = EMPTY_STRING

        a : Int32? = 10

        klass = String?

        my_var.as(Array(Char))

        puts StaticArray(Int32, 10)

        # Not a union
        Int32 | "Float64"

        MyClass(String).new.run
        CRYSTAL
    end

    it "passes for plain pseudo methods, self, and paths" do
      expect_no_issues subject, <<-CRYSTAL
        _
        self
        self?
        typeof(1)
        Int32
        CRYSTAL
    end

    it "passes if generics and unions are used for method arguments and return type" do
      expect_no_issues subject, <<-CRYSTAL
        def size(a : Float64?) : Float64?
          0.1.try(&.+(a))
        end

        def append(a : Array(String)) : Array(String)
          a << "hello"
        end
        CRYSTAL
    end

    it "fails if generics or unions are unused at top-level" do
      expect_issue subject, <<-CRYSTAL
        String?
        # ^^^^^ error: Generic is not used
        Int32 | Float64 | Nil
        # ^^^^^^^^^^^^^^^^^^^ error: Union is not used
        StaticArray(Int32, 10)
        # ^^^^^^^^^^^^^^^^^^^^ error: Generic is not used
        CRYSTAL
    end

    it "fails if generics or unions are unused inside methods" do
      expect_issue subject, <<-CRYSTAL
        def hello
          Float64?
        # ^^^^^^^^ error: Generic is not used
          0.1
        end

        fun fun_name : Int32
          Array(String)
        # ^^^^^^^^^^^^^ error: Generic is not used
          1234
        end
        CRYSTAL
    end

    it "fails if generics or unions are unused inside classes and modules" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          String?
        # ^^^^^^^ error: Generic is not used
          Array(self)
        # ^^^^^^^^^^^ error: Generic is not used
          Array(typeof(1))
        # ^^^^^^^^^^^^^^^^ error: Generic is not used

          def hello
            self | Nil
          # ^^^^^^^^^^ error: Union is not used
            typeof(1) | Nil | _
          # ^^^^^^^^^^^^^^^^^^^ error: Union is not used
            "Hello, Gordon!"
          end
        end

        module MyModule
          Array(Int32)
        # ^^^^^^^^^^^^ error: Generic is not used
        end
        CRYSTAL
    end
  end
end

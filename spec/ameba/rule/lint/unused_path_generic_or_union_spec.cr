require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedPathGenericOrUnion.new

  describe UnusedPathGenericOrUnion do
    it "passes if paths and generic types are used" do
      expect_no_issues subject, <<-CRYSTAL
        MyConst = 1

        my_var : String? = EMPTY_STRING

        my_var.as(String)

        puts StaticArray(Int32, 10)

        class MyClass < MySuperClass
          include MyModule
          extend MyModule
        end

        a : Int32 = 10

        klass = String?

        alias MyType = Float64 | StaticArray(Float64, 10)

        def size : Float64
          0.1
        end

        lib MyLib
          type MyType = Void*

          struct MyStruct
            field1, field2 : Float64
          end
        end

        fun fun_name : Int32
          1234
        end

        Int32 | "Float64"

        MyClass.run
        CRYSTAL
    end

    it "fails if paths and generic types are top-level" do
      expect_issue subject, <<-CRYSTAL
        Int32
        # ^^^ error: Path or generic type is not used
        String?
        # ^^^^^ error: Path or generic type is not used
        Int32 | Float64 | Nil
        # ^^^^^^^^^^^^^^^^^^^ error: Path or generic type is not used
        StaticArray(Int32, 10)
        # ^^^^^^^^^^^^^^^^^^^^ error: Path or generic type is not used

        def hello
          Float64
        # ^^^^^^^ error: Path or generic type is not used
          0.1
        end

        fun fun_name : Int32
          Int32
        # ^^^^^ error: Path or generic type is not used
          1234
        end

        class MyClass
          MyModule
        # ^^^^^^^^ error: Path or generic type is not used
        end
        CRYSTAL
    end
  end
end

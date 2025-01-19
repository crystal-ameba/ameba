require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedTypeOrConstant.new

  describe UnusedTypeOrConstant do
    it "passes if paths and generic types are used for assign and method calls" do
      expect_no_issues subject, <<-CRYSTAL
        MyConst = 1

        my_var : String? = EMPTY_STRING

        a : Int32 = 10

        klass = String?

        my_var.as(String)

        puts StaticArray(Int32, 10)

        Int32 | "Float64"

        MyClass.run
        CRYSTAL
    end

    it "passes if paths are used for methods" do
      expect_no_issues subject, <<-CRYSTAL
        def size(a : Float64) : Float64
          0.1 + a
        end

        fun fun_name = FunName(a : Int32) : Int32
          1234 + a
        end
        CRYSTAL
    end

    it "passes if paths are used for classes, modules, aliases, and annotations" do
      expect_no_issues subject, <<-CRYSTAL
        module MyModule(T)
          struct MyStruct < MySuperStruct
          end
        end

        @[MyAnnotation]
        class MyClass < MySuperClass
          include MyModule(Int23)
          extend MyModule(String)

          alias MyType = Float64 | StaticArray(Float64, 10)
        end

        annotation MyAnnotation
        end
        CRYSTAL
    end

    it "passes if paths are used for lib objects" do
      expect_no_issues subject, <<-CRYSTAL
        lib MyLib
          $external_var = ExternalVarName : Int32

          type MyType = Void*

          struct MyStruct
            field1, field2 : Float64
          end

          fun fun_name = FunName(Void*) : Void
        end
        CRYSTAL
    end

    it "fails if paths and generic types are unused top-level" do
      expect_issue subject, <<-CRYSTAL
        Int32
        # ^^^ error: Type or constant is not used
        String?
        # ^^^^^ error: Type or constant is not used
        Int32 | Float64 | Nil
        # ^^^^^^^^^^^^^^^^^^^ error: Type or constant is not used
        StaticArray(Int32, 10)
        # ^^^^^^^^^^^^^^^^^^^^ error: Type or constant is not used
        CRYSTAL
    end

    it "fails if types and constants are unused inside methods" do
      expect_issue subject, <<-CRYSTAL
        def hello
          Float64
        # ^^^^^^^ error: Type or constant is not used
          0.1
        end

        fun fun_name : Int32
          Int32
        # ^^^^^ error: Type or constant is not used
          1234
        end
        CRYSTAL
    end

    it "fails if types and constants are unused inside classes and modules" do
      expect_issue subject, <<-CRYSTAL
        class MyClass
          MyModule
        # ^^^^^^^^ error: Type or constant is not used
        end

        module MyModule
          Int32
        # ^^^^^ error: Type or constant is not used
        end
        CRYSTAL
    end
  end
end
